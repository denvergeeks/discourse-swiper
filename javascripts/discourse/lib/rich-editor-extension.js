import { camelize } from "@ember/string";
import { deepMerge } from "discourse/lib/object";
import SwiperNodeView from "../components/swiper-node-view";
import GlimmerNodeView from "../lib/glimmer-node-view";
import { changedDescendants } from "../lib/rich-editor-utils";
import { DEFAULT_SETTINGS, SWIPER_NODEVIEW_CLASS } from "./constants";
import { flattenObject, normalizeSettings } from "./utils";

const extension = {
  name: "swiper",

  nodeSpec: {
    swiper: {
      content: "block*",
      group: "block",
      selectable: true,
      draggable: true,
      isolating: true,
      createGapCursor: true,
      atom: true,
      attrs: {
        ...flattenObject({ ...DEFAULT_SETTINGS }, { withDefault: true }),
        mode: { default: "view" }, // 'view' or 'edit'
      },
      parseDOM: [
        {
          tag: "div[data-wrap=swiper]",
          getAttrs: (dom) => {
            return {
              ...dom.dataset.reduce((attrs, value, key) => {
                if (value.includes(":")) {
                  // param="key: value, key2: value2" => param="key: value, key2: value2"
                  attrs[key] = value.split(",").reduce((object, pair) => {
                    const [k, v] = pair.split(":").map((s) => s.trim());
                    if (k && v !== undefined) {
                      object[k] = v;
                    }
                    return object;
                  }, {});
                  return attrs;
                }

                attrs[key] = value;
                return attrs;
              }, {}),
            };
          },
        },
      ],
      toDOM: (node) => {
        const attrs = { class: "d-wrap" };
        for (const [key, value] of Object.entries(node.attrs)) {
          if (value === null) {
            continue;
          }

          if (typeof value === "object") {
            // param="key: value, key2: value2" => param="key: value, key2: value2"
            attrs[`data-${key}`] = Object.entries(value)
              .map(([k, v]) => `${k}: ${v}`)
              .join(", ");
          } else {
            attrs[`data-${key}`] = value;
          }
        }
        return ["div", attrs, 0];
      },
    },
    // Placeholder node to help with cursor positioning at the end of the paragraph
    swiper_placeholder: {
      content: "",
      group: "inline",
      inline: true,
      atom: true,
      selectable: true,

      parseDOM: [
        {
          tag: "div.swiper-placeholder",
        },
      ],
      toDOM: () => {
        return ["div", { class: "swiper-placeholder" }];
      },
    },
  },

  nodeViews: {
    swiper:
      ({ getContext }) =>
      (node, view, getPos) => {
        return new GlimmerNodeView({
          node,
          view,
          getPos,
          getContext,
          component: SwiperNodeView,
          name: "swiper",
        });
      },
  },

  parse: {
    wrap_open(state, token) {
      if (token.attrGet("data-wrap") === "swiper") {
        const attrs = Object.fromEntries(
          token.attrs
            .filter(([key]) => key.startsWith("data-"))
            .map(([key, value]) => [camelize(key.slice(5)), value])
            .map(([key, value]) => {
              // param="key: value, key2: value2" => param: { key: value, key2: value2 }
              if (value.includes(":")) {
                const parsedValue = value.split(",").reduce((object, pair) => {
                  const [k, v] = pair.split(":").map((s) => s.trim());
                  if (k && v !== undefined) {
                    object[k] = v;
                  }
                  return object;
                }, {});
                return [key, parsedValue];
              }
              return [key, value];
            })
        );

        state.openNode(
          state.schema.nodes.swiper,
          deepMerge({}, DEFAULT_SETTINGS, attrs)
        );
        return true;
      }
    },
    wrap_close(state) {
      if (state.top().type.name === "swiper") {
        state.closeNode();
        return true;
      }
    },
  },
  serializeNode: {
    swiper(state, node) {
      state.write("[wrap=swiper");

      Object.entries(normalizeSettings(node.attrs)).forEach(([key, value]) => {
        if (key === "mode" || value === null) {
          return;
        }

        let newValue = value;
        // Serialize object attributes as key: value, key2: value2
        if (typeof value === "object" && !Array.isArray(value)) {
          let subValues = [];
          for (const [subkey, subvalue] of Object.entries(value)) {
            if (DEFAULT_SETTINGS[key][subkey] !== subvalue) {
              subValues.push(`${subkey}: ${subvalue}`);
            }
          }
          if (subValues.length === 0) {
            return;
          }
          newValue = subValues.join(", ");
        } else if (DEFAULT_SETTINGS[key] === value) {
          return;
        }

        state.write(` ${key}="${newValue}"`);
      });

      state.write("]\n");

      if (node.content.size > 0) {
        const startPos = state.out.length;
        state.renderContent(node);
        const endPos = state.out.length;

        // Post-process: add newlines before images (except first)
        const content = state.out.substring(startPos, endPos);
        const withNewlines = content.replace(
          /(\]\(upload:\/\/[^)]+\))!\n*/g,
          "$1\n!"
        );
        state.out =
          state.out.substring(0, startPos) +
          withNewlines +
          state.out.substring(endPos);
      }

      state.write("[/wrap]\n\n");
    },
    swiper_placeholder(state /*, node*/) {
      // Placeholder node doesn't serialize to anything
      // It's just a visual indicator in the editor
      state.write("");
    },
  },
  plugins({
    pmState: { Plugin, NodeSelection, Selection, TextSelection, PluginKey },
    pmModel: { Fragment },
  }) {
    const swiperPlugin = new Plugin({
      key: new PluginKey("swiper"),

      // Normalize swiper nodes to ensure they contain only images for now.
      // TODO: others elements such as videos, oneboxes, etc?
      appendTransaction(transactions, oldState, newState) {
        if (
          transactions.some(
            (tr) => tr.getMeta("swiperNormalization") || !tr.docChanged
          )
        ) {
          return null;
        }

        let tr = null;
        const swipersToNormalize = new Set();

        changedDescendants(oldState.doc, newState.doc, (node, pos) => {
          if (node.type.name === "swiper") {
            swipersToNormalize.add(pos);
          }

          // If something inside a swiper changed, mark parent swiper
          const $pos = newState.doc.resolve(pos);
          for (let d = $pos.depth; d > 0; d--) {
            if ($pos.node(d).type.name === "swiper") {
              swipersToNormalize.add($pos.before(d));
              break;
            }
          }
        });

        // Sort positions in descending order to prevent position invalidation issues
        const sortedPositions = Array.from(swipersToNormalize).sort(
          (a, b) => b - a
        );

        sortedPositions.forEach((pos) => {
          // Map the position through any previous transaction changes
          const mappedPos = tr ? tr.mapping.map(pos) : pos;
          const doc = tr ? tr.doc : newState.doc;

          const node = doc.nodeAt(mappedPos);
          if (!node || node.type.name !== "swiper") {
            return;
          }

          const images = [];
          let hasUnresolvedImages = false;

          node.forEach((child) => {
            child.content?.forEach((inlineNode) => {
              if (inlineNode.type.name === "image") {
                images.push(inlineNode);

                if (inlineNode.attrs.src?.endsWith("/images/transparent.png")) {
                  hasUnresolvedImages = true;
                }
              }
            });
          });

          if (hasUnresolvedImages) {
            return;
          }

          // We expect to have
          // <p>
          //   <image></image>
          //   <image></image>
          //   ...
          //   swiper_placeholder
          // </p >

          const needsNormalization = (() => {
            if (node.childCount !== 1) {
              return true;
            }

            const firstChild = node.firstChild;
            if (firstChild.type.name !== "paragraph") {
              return true;
            }

            if (images.length === 0) {
              if (firstChild.childCount !== 1) {
                return true;
              }

              return firstChild.firstChild?.type.name !== "swiper_placeholder";
            }

            // images + placeholder
            if (firstChild.childCount !== images.length + 1) {
              return true;
            }

            let hasWrongStructure = false;
            firstChild.content.forEach((inlineNode, idx) => {
              if (idx === images.length) {
                if (inlineNode.type.name !== "swiper_placeholder") {
                  hasWrongStructure = true;
                }
              } else {
                if (
                  inlineNode.type.name !== "image" ||
                  inlineNode !== images[idx]
                ) {
                  hasWrongStructure = true;
                }
              }
            });

            return hasWrongStructure;
          })();

          if (!needsNormalization) {
            return;
          }

          // One paragraph with only images + swiper_placeholder
          const newSwiper = node.type.create(
            node.attrs,
            newState.schema.nodes.paragraph.create(
              null,
              Fragment.fromArray(
                images.length > 0
                  ? [
                      ...images,
                      newState.schema.nodes.swiper_placeholder.create(),
                    ]
                  : []
              )
            )
          );

          if (!tr) {
            tr = newState.tr;
          }

          tr.replaceWith(mappedPos, mappedPos + node.nodeSize, newSwiper);

          // Make sure to re-select paragraph, useful for multiple uploads.
          const updatedNode = tr.doc.nodeAt(mappedPos);
          if (updatedNode?.attrs.mode === "edit") {
            // Place cursor before the placeholder
            tr.setSelection(
              TextSelection.create(
                tr.doc,
                mappedPos +
                  2 +
                  updatedNode.firstChild.content.size -
                  newState.schema.nodes.swiper_placeholder.create().nodeSize
              )
            );
          }
        });

        if (tr) {
          tr.setMeta("addToHistory", false);
          tr.setMeta("swiperNormalization", true);
        }

        return tr;
      },

      props: {
        handleDOMEvents: {
          // Track dragging images into swipers
          dragstart(view, event) {
            if (!event.target.closest(SWIPER_NODEVIEW_CLASS)) {
              view._swiperPM.movingImageToSwiper = event.target;
              return true;
            }
          },
          drop(view /*, event*/) {
            view._swiperPM.movingImageToSwiper = null;
          },
        },
        handleClickOn(view, pos, node, nodePos, event) {
          if (node.type.name === "swiper") {
            if (event.target.localName === "img") {
              return;
            }

            // When swiper is the first element in the editor, clicking on it
            // doesn't place the cursor inside. We do it manually.
            if (nodePos > 0) {
              return;
            }

            const tr = view.state.tr.setSelection(
              TextSelection.create(view.state.doc, nodePos)
            );
            view.dispatch(tr);
            return true;
          }
        },
      },
      view(editorView) {
        // can't use import and getContext is not passed to nodeView.component
        // so setting into the view for access there. Is there other way?
        editorView._swiperPM = {
          NodeSelection,
          TextSelection,
          Selection,
        };

        return {
          // In edit mode, selects nodeview container if we do stuff inside it.
          update(view, prevState) {
            if (view.state.selection.eq(prevState.selection)) {
              return;
            }

            const { from, to } = view.state.selection;

            view.state.doc.descendants((node, pos) => {
              if (node.type.name === "swiper") {
                const nodeStart = pos;
                const nodeEnd = pos + node.nodeSize;
                const isInside =
                  (from >= nodeStart && from < nodeEnd) ||
                  (to > nodeStart && to <= nodeEnd) ||
                  (from < nodeStart && to > nodeEnd);

                const nodeView = view.nodeDOM(pos);
                if (nodeView) {
                  if (isInside) {
                    nodeView.classList.add("has-selection");
                  } else {
                    nodeView.classList.remove("has-selection");
                  }
                }
              }
            });
          },
        };
      },
    });

    return [/*dropPlaceholderPlugin*/ swiperPlugin];
  },
};

export default extension;
