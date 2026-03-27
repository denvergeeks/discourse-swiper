import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import { ToolbarBase } from "discourse/lib/composer/toolbar";
import { createDragImage, deepTrack } from "../lib/utils";
import SwiperInline from "./swiper-inline";
import SwiperSettingsPanel from "./swiper-settings-panel";

const MENU_PADDING = 8;

let menuIndex = 0;

class SwiperLeftToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    if (opts.editMode) {
      this.addButton({
        id: "swiper-validate",
        icon: "circle-check",
        title: themePrefix("composer.swiper.toolbar.validate"),
        className: "composer-swiper-toolbar__validate",
        action: opts.editSwiper,
        get disabled() {
          return !opts.hasImages();
        },
        tabindex: 0,
      });
    } else {
      this.addButton({
        id: "swiper-edit",
        icon: "pencil",
        title: themePrefix("composer.swiper.toolbar.edit"),
        className: "composer-swiper-toolbar__edit",
        action: opts.editSwiper,
        tabindex: 0,
      });

      this.addButton({
        id: "swiper-settings",
        icon: "gear",
        title: themePrefix("composer.swiper.toolbar.settings"),
        className: "composer-swiper-toolbar__settings",
        action: opts.openSettings,
        tabindex: 0,
      });
    }
  }
}

class SwiperRightToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    this.addButton({
      id: "swiper-delete",
      icon: "trash-can",
      title: themePrefix("composer.swiper.toolbar.delete"),
      className: "composer-swiper-toolbar__delete",
      action: opts.deleteSwiper,
      tabindex: 0,
    });
  }
}

class ReorderImageToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    this.addButton({
      id: "swiper-move-image-left",
      icon: "arrow-left",
      title: themePrefix("composer.swiper.toolbar.move_left"),
      className: "composer-swiper-mobile-toolbar__move-left",
      action: opts.moveImageLeft,
      get disabled() {
        return opts.isAtStart();
      },
      tabindex: 0,
    });

    this.addButton({
      id: "swiper-move-image-right",
      icon: "arrow-right",
      title: themePrefix("composer.swiper.toolbar.move_right"),
      className: "composer-swiper-mobile-toolbar__move-right",
      action: opts.moveImageRight,
      get disabled() {
        return opts.isAtEnd();
      },
      tabindex: 0,
    });
  }
}

export default class SwiperNodeView extends Component {
  @service menu;
  @service capabilities;
  @service activeSwiperInEditor;

  @tracked isEditMode = false;
  @tracked selectedImageIndex = -1;

  swiperToolbar = { left: null, right: null };
  menuInstance = { left: null, right: null };

  lastSelectedImageForDrop = null;

  constructor() {
    super(...arguments);

    this.menuIndex = ++menuIndex;
    this.args.onSetup?.(this);
  }

  willDestroy() {
    this.closeMenus();
    this.closeSettingsMenu();

    super.willDestroy(...arguments);
  }

  @cached
  get config() {
    return deepTrack(this.args.node.attrs);
  }

  @action
  setupSwiperWrap(element) {
    this.swiperWrap = element;

    if (!this.imageCount) {
      this.toggleEditMode();
    }
  }

  get contentDOM() {
    return this.args.dom.firstElementChild;
  }

  async showMobileToolbar() {
    this.reorderImageToolbar ??= new ReorderImageToolbar({
      moveImageLeft: this.moveSelectedImage.bind(this, -1),
      moveImageRight: this.moveSelectedImage.bind(this, 1),
      isAtStart: () => this.selectedImageIndex === 0,
      isAtEnd: () => this.selectedImageIndex >= this.imageCount - 1,
    });

    this.mobileMenuInstance = await this.menu.newInstance(this.args.dom, {
      identifier: `composer-swiper-nav-toolbar-${this.menuIndex}`,
      component: ToolbarButtons,
      placement: "top-center",
      padding: MENU_PADDING,
      data: this.reorderImageToolbar,
      portalOutletElement: this.args.dom,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      trapTab: false,
      offset({ rects }) {
        return {
          mainAxis: -MENU_PADDING - rects.floating.height,
          crossAxis: MENU_PADDING,
        };
      },
    });

    await this.mobileMenuInstance.show();
  }

  async showToolbar() {
    this.swiperToolbar.left ??= new SwiperLeftToolbar({
      editSwiper: this.toggleEditMode.bind(this),
      openSettings: this.openSettings.bind(this),
      deleteSwiper: this.deleteSwiper.bind(this),
      editMode: this.isEditMode,
      hasImages: () => this.imageCount > 0,
    });

    this.swiperToolbar.right ??= new SwiperRightToolbar({
      deleteSwiper: this.deleteSwiper.bind(this),
    });

    // Add unique identifier in edit mode to allow multiple menus (swiper)
    const extraIdentifier = this.isEditMode ? `-edit-${this.menuIndex}` : "";

    const leftOptions = {
      identifier: `composer-swiper-toolbar--left${extraIdentifier}`,
      component: ToolbarButtons,
      placement: "top-start",
      fallbackPlacements: ["top-start"],
      padding: MENU_PADDING,
      data: this.swiperToolbar.left,
      portalOutletElement: this.args.dom,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      trapTab: false,
      offset({ rects }) {
        return {
          mainAxis: -MENU_PADDING - rects.floating.height,
          crossAxis: MENU_PADDING,
        };
      },
      limitShift: {
        // Keep shifting vertically within container
        offset: ({ rects, placement }) => ({
          crossAxis:
            (-rects.floating.height - MENU_PADDING) *
            (placement.includes("start") ? -1 : 1),
        }),
      },
    };

    const rightOptions = {
      ...leftOptions,
      identifier: `composer-swiper-toolbar--right${extraIdentifier}`,
      data: this.swiperToolbar.right,
      placement: "top-end",
      fallbackPlacements: ["top-end"],
      offset({ rects }) {
        return {
          mainAxis: -MENU_PADDING - rects.floating.height,
          crossAxis: -MENU_PADDING,
        };
      },
    };

    this.menuInstance = {
      left: await this.menu.newInstance(this.args.dom, leftOptions),
      right: await this.menu.newInstance(this.args.dom, rightOptions),
    };

    await this.menuInstance.left.show();
    await this.menuInstance.right.show();
  }

  selectNode() {
    if (this.isEditMode) {
      return;
    }

    this.args.dom.classList.add("ProseMirror-selectednode");

    this.activeSwiperInEditor.setTo(
      this.swiperWrap?.querySelector(".main-slider")?.swiper || null
    );

    this.showToolbar();
  }

  deselectNode() {
    if (this.isEditMode) {
      return;
    }

    if (this.args.dom.classList.contains("has-selection")) {
      const { NodeSelection } = this.args.view._swiperPM;
      this.args.view.dispatch(
        this.args.view.state.tr.setSelection(
          NodeSelection.create(this.args.view.state.doc, this.args.getPos())
        )
      );
      this.args.view.focus();
    } else {
      this.args.dom.classList.remove("ProseMirror-selectednode");
      this.activeSwiperInEditor.setTo(null);

      this.closeMenus();
      this.closeSettingsMenu();
    }
  }

  closeModeMenu() {
    ["left", "right"].forEach((side) => {
      this.menuInstance[side]?.close();
      this.menuInstance[side] = null;
      this.swiperToolbar[side] = null;
    });
  }

  closeMobileMenu() {
    this.mobileMenuInstance?.close();
    this.reorderImageToolbar = null;
    this.mobileMenuInstance = null;
  }

  closeMenus() {
    this.closeModeMenu();
    this.closeMobileMenu();
  }

  @action
  toggleEditMode() {
    this.isEditMode = !this.isEditMode;

    this.closeMenus();
    this.closeSettingsMenu();
    this.showToolbar();

    const { view, dom, getPos, node } = this.args;

    if (this.isEditMode) {
      this.swiperWrap.classList.add("hidden");

      dom.classList.add("edit");

      const pos = getPos();
      const tr = view.state.tr.setNodeMarkup(pos, null, {
        ...node.attrs,
        mode: "edit",
      });

      view.dispatch(tr);
      view.focus();

      // Ensure the node is entirely visible
      dom.scrollIntoView({ block: "center" });
    } else {
      this.swiperWrap.classList.remove("hidden");

      dom.classList.remove("edit");

      const pos = getPos();
      const tr = view.state.tr.setNodeMarkup(pos, null, {
        ...node.attrs,
        mode: "view",
      });

      view.dispatch(tr);
      view.focus();
      view.dispatch(view.state.tr.scrollIntoView());
    }
  }

  @action
  async openSettings() {
    if (this.settingsMenu) {
      this.closeSettingsMenu();
      return;
    }

    this.settingsMenu ??= await this.menu.newInstance(
      document.querySelector("#reply-control"),
      {
        identifier: `composer-swiper-settings-` + this.menuIndex,
        component: SwiperSettingsPanel,
        closeOnClickOutside: false,
        closeOnEscape: false,
        closeOnScroll: false,
        trapTab: true,
        modalForMobile: true,
        placement: "left-start",
        autofocus: true,
        autoUpdate: false,
        updateOnScroll: false,
        strategy: "fixed",
        data: {
          view: this.args.view,
          getPos: this.args.getPos,
          getConfig: () => this.config,
          closeSettingsMenu: this.closeSettingsMenu.bind(this),
        },
      }
    );

    await this.settingsMenu.show();
  }

  closeSettingsMenu() {
    if (this.settingsMenu) {
      this.menu.close(this.settingsMenu);
      this.settingsMenu = null;
    }
  }

  @action
  deleteSwiper() {
    const { view, getPos } = this.args;
    const pos = getPos();
    const tr = view.state.tr.delete(pos, pos + this.args.node.nodeSize);

    view.dispatch(tr);
    view.focus();
  }

  stopEvent(event) {
    const { type, target } = event;

    // View mode: let Swiper handles everything
    if (
      !this.isEditMode &&
      !this.contentDOM.contains(target) &&
      target.closest(".swiper-wrap")
    ) {
      // Prevents native image drag
      if (type === "dragstart" && target.tagName === "IMG") {
        event.preventDefault();
      }
      return true;
    }

    // Edit mode: only handle events inside contentDOM
    if (!this.isEditMode || !this.contentDOM.contains(target)) {
      return false;
    }

    const isTargetImage = target.tagName === "IMG";

    // Cursor positioning
    // Grid layout breaks PM's click-to-position mapping in gaps between items.
    if (type === "mousedown" && !isTargetImage) {
      this.#placeCursorAtCoords(event);
      return true;
    }

    // Touch buttons
    if (type === "touchstart") {
      if (isTargetImage) {
        this.contentDOM
          .querySelectorAll(".composer-image-node")
          .forEach((node) => node.classList.remove("mobile-selected"));
        this.selectedImageNode = target;
        this.selectedImageNode.parentElement.classList.add("mobile-selected");
        this.#updateSelectedImageIndex();

        if (this.capabilities.touch) {
          this.showMobileToolbar();
        }
      } else {
        this.#clearMobileSelection();
      }
      return false;
    }

    // Image reordering & external file drops
    switch (type) {
      case "dragstart":
        if (!isTargetImage) {
          break;
        }

        this.reorderingImage = {
          from: target,
          isSelected: target
            .closest(".composer-image-node")
            ?.firstElementChild?.classList.contains("ProseMirror-selectednode"),
        };

        createDragImage(event, {
          width: target.closest(".composer-image-node").offsetWidth,
          height: target.closest(".composer-image-node").offsetHeight,
          scale: 0.6,
        });

        this.contentDOM.classList.add("active-dragging");
        event.stopPropagation();
        return true;

      case "dragenter":
        if (isTargetImage) {
          this.contentDOM.classList.add("active-dragging");
        }
        return false;

      case "dragover": {
        const isExternalDrag = event.dataTransfer?.types.includes("Files");
        if (!this.reorderingImage && !isExternalDrag) {
          break;
        }

        this.contentDOM.classList.add("active-dragging");

        try {
          this.selectClosestImageToCursor(event);
        } catch {
          this.lastSelectedImageForDrop = null;
        }

        if (!this.externalDragSuppressed) {
          this.externalDragSuppressed = true;
          const { view } = this.args;
          view.dispatch(view.state.tr.setMeta("swiperExternalDrag", true));
        }

        return true;
      }

      case "drop":
        this.#resetDragState();

        if (this.reorderingImage) {
          event.preventDefault();
          event.stopPropagation();

          this.handleImageDrop(
            {
              view: this.args.view,
              getPos: this.args.getPos,
              node: this.args.node,
            },
            event,
            this.reorderingImage.from,
            this.reorderingImage.isSelected
          );

          this.reorderingImage = null;
          return true;
        }
        break;

      case "dragleave":
        if (!this.contentDOM.contains(event.relatedTarget)) {
          this.#resetDragState();
        }
        break;

      case "dragend":
        this.reorderingImage = null;
        this.#resetDragState();
        break;
    }

    return false;
  }

  #placeCursorAtCoords(event) {
    const { view, getPos, node } = this.args;
    const { TextSelection } = view._swiperPM;
    const swiperPos = getPos();

    const coords = view.posAtCoords({
      left: event.clientX,
      top: event.clientY,
    });

    const targetPos =
      coords?.pos > swiperPos && coords.pos < swiperPos + node.nodeSize
        ? coords.pos
        : swiperPos + 2 + node.firstChild.content.size;

    view.dispatch(
      view.state.tr.setSelection(
        TextSelection.create(view.state.doc, targetPos)
      )
    );
    view.focus();
  }

  #updateSelectedImageIndex() {
    if (!this.selectedImageNode) {
      this.selectedImageIndex = -1;
      return;
    }

    const images = this.#getImagePositions();
    this.selectedImageIndex = images.findIndex(
      (img) =>
        img.node.attrs.originalSrc ===
        this.selectedImageNode.getAttribute("data-orig-src")
    );
  }

  #clearMobileSelection() {
    this.contentDOM
      .querySelectorAll(".composer-image-node")
      .forEach((node) => node.classList.remove("mobile-selected"));
    this.selectedImageNode = null;
    this.selectedImageIndex = -1;
    this.closeMobileMenu();
  }

  #resetDragState() {
    this.lastSelectedImageForDrop = null;
    this.contentDOM.classList.remove("active-dragging");

    if (this.externalDragSuppressed) {
      this.externalDragSuppressed = false;
      const { view } = this.args;
      view.dispatch(view.state.tr.setMeta("swiperExternalDrag", false));
    }
  }

  #getImagePositions(node = this.args.node, pos = this.args.getPos()) {
    const paragraph = node.firstChild;
    const images = [];
    let offset = 0;

    paragraph.content.forEach((child) => {
      if (child.type.name === "image") {
        images.push({
          node: child,
          pos: pos + 2 + offset, // +2 for swiper open + paragraph open
          size: child.nodeSize,
        });
      }
      offset += child.nodeSize;
    });

    return images;
  }

  handleImageDrop(
    { view, getPos, node },
    event,
    draggedImageElement,
    draggedImageIsSelected
  ) {
    const imageElements = Array.from(
      this.contentDOM.querySelectorAll(".composer-image-node img")
    );
    const draggedIndex = imageElements.indexOf(draggedImageElement);

    if (draggedIndex === -1) {
      return false;
    }

    const coords = view.posAtCoords({
      left: event.clientX,
      top: event.clientY,
    });

    if (!coords) {
      return false;
    }

    const images = this.#getImagePositions(node, getPos());

    let targetIndex = 0;
    for (let i = 0; i < images.length; i++) {
      if (coords.pos > images[i].pos + images[i].size / 2) {
        targetIndex = i + 1;
      } else {
        break;
      }
    }

    if (draggedIndex < targetIndex) {
      targetIndex--;
    }

    if (draggedIndex === targetIndex) {
      return false;
    }

    const sourceImage = images[draggedIndex];
    const targetImage = images[targetIndex];
    const tr = view.state.tr;

    tr.delete(sourceImage.pos, sourceImage.pos + sourceImage.size);

    const insertPos =
      draggedIndex < targetIndex
        ? targetImage.pos - sourceImage.size + targetImage.size
        : targetImage.pos;

    tr.insert(insertPos, sourceImage.node);

    const SelectionType = draggedImageIsSelected
      ? view._swiperPM.NodeSelection
      : view._swiperPM.TextSelection;
    tr.setSelection(SelectionType.create(tr.doc, insertPos));

    view.dispatch(tr);

    // Moves cursor to the moved image
    const { TextSelection } = view._swiperPM;
    view.dispatch(
      view.state.tr.setSelection(
        TextSelection.create(view.state.doc, insertPos)
      )
    );

    // Re-selects image if it was selected before
    if (draggedImageIsSelected) {
      const { NodeSelection } = view._swiperPM;
      view.dispatch(
        view.state.tr.setSelection(
          NodeSelection.create(view.state.doc, insertPos)
        )
      );
    }

    return true;
  }

  selectClosestImageToCursor(event) {
    const { view, node, getPos } = this.args;

    if (!view || !node || !getPos) {
      return;
    }

    const coords = view.posAtCoords({
      left: event.clientX,
      top: event.clientY,
    });

    if (!coords || coords.pos == null) {
      return;
    }

    const dropPos = coords.pos;
    const swiperPos = getPos();
    const swiperEnd = swiperPos + node.nodeSize;

    if (dropPos < swiperPos || dropPos > swiperEnd) {
      return;
    }

    if (this.lastSelectedImageForDrop === dropPos) {
      return;
    }

    this.lastSelectedImageForDrop = dropPos;

    const tr = view.state.tr;
    const { TextSelection } = view._swiperPM;

    try {
      const $pos = tr.doc.resolve(dropPos);
      const selection = TextSelection.near($pos);

      if (!selection) {
        this.lastSelectedImageForDrop = null;
        return;
      }

      tr.setMeta("swiperDropPosition", dropPos);
      tr.setSelection(selection);
      view.dispatch(tr);
    } catch {
      this.lastSelectedImageForDrop = null;
    }
  }

  @action
  moveSelectedImage(direction) {
    if (!this.selectedImageNode) {
      return;
    }

    const images = this.#getImagePositions();
    const currentIndex = images.findIndex(
      (img) =>
        img.node.attrs.originalSrc ===
        this.selectedImageNode.getAttribute("data-orig-src")
    );

    if (currentIndex === -1) {
      return;
    }

    const newIndex = currentIndex + direction;
    if (newIndex < 0 || newIndex >= images.length) {
      return;
    }

    this.moveImageAt(currentIndex, newIndex);
    this.selectedImageIndex = newIndex;

    // Re-select the image at new position
    next(() => {
      const { view } = this.args;
      const { NodeSelection } = view._swiperPM;
      const updatedImages = this.#getImagePositions();

      if (updatedImages[newIndex]) {
        const tr = view.state.tr;
        tr.setSelection(
          NodeSelection.create(tr.doc, updatedImages[newIndex].pos)
        );
        view.dispatch(tr);
      }
    });
  }

  @action
  moveImageAt(sourceIndex, targetIndex) {
    const { view } = this.args;
    const images = this.#getImagePositions();

    if (sourceIndex >= images.length || targetIndex >= images.length) {
      return;
    }

    const sourceImage = images[sourceIndex];
    const targetImage = images[targetIndex];
    const tr = view.state.tr;

    tr.delete(sourceImage.pos, sourceImage.pos + sourceImage.size);

    const insertPos =
      sourceIndex < targetIndex
        ? targetImage.pos - sourceImage.size + targetImage.size
        : targetImage.pos;

    tr.insert(insertPos, sourceImage.node);
    view.dispatch(tr);
  }

  get imageNodes() {
    return (
      this.args.node.firstChild?.content.content.filter(
        (child) => child.type.name === "image"
      ) ?? []
    );
  }

  get imageCount() {
    return this.imageNodes.length;
  }

  <template>
    {{#unless this.isEditMode}}
      <SwiperInline
        @node={{hash
          images=this.imageNodes
          config=this.config
          onSetup=this.setupSwiperWrap
          onClick=this.containerClick
        }}
      />
    {{/unless}}
  </template>
}
