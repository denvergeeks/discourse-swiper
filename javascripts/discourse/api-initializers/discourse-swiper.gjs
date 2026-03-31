import { camelize } from "@ember/string";
import { apiInitializer } from "discourse/lib/api";
import SwiperInline from "../components/swiper-inline";
import MediaElementParser from "../lib/media-element-parser";
import swiperExtension from "../lib/rich-editor-extension";
import { parseWrapParam } from "../lib/utils";

export default apiInitializer((api) => {
  initializeSwiper(api);
});

function initializeSwiper(api) {
  function applySwiper(element, helper) {
    const isPreview = !helper?.model;
    const container = document.createElement("div");
    container.classList.add("swiper-wrap-container");

    for (const [key, value] of Object.entries(element.dataset)) {
      container.dataset[camelize(key)] = value;
    }

    const config = parseWrapParam({ ...element.dataset });
    
    // Parse topics parameter
    if (element.dataset.topics) {
      config.topics = element.dataset.topics.split(',').map(id => id.trim());
    }

    helper.renderGlimmer(container, SwiperInline, {
      preview: isPreview,
            config: config,
      parsedData: MediaElementParser.run(element),
    });

    element.replaceWith(container);
  }

  api.decorateCookedElement((element, helper) => {
    element
      .querySelectorAll("[data-wrap=swiper]")
      .forEach((swiper) => applySwiper(swiper, helper));
  });

  api.registerRichEditorExtension(swiperExtension);

  window.I18n.translations[window.I18n.locale].js.composer.swiper_sample = "";

  api.addComposerToolbarPopupMenuOption({
    icon: "images",
    label: themePrefix("insert_swiper_sample"),
    action: (toolbarEvent) => {
      toolbarEvent.applySurround(
        "\n[wrap=swiper]\n",
        "\n[/wrap]\n",
        "swiper_sample",
        {
          multiline: false,
        }
      );
    },
  });
}
