import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, eq } from "truth-helpers";
import noop from "discourse/helpers/noop";
import lightbox from "discourse/lib/lightbox";
import loadScript from "discourse/lib/load-script";
import { deepMerge } from "discourse/lib/object";
import { escapeExpression } from "discourse/lib/utilities";
import { ajax } from "discourse/lib/ajax";
import { DEFAULT_SETTINGS } from "../lib/constants";
import { normalizeSettings } from "../lib/utils";

export default class SwiperInline extends Component {
  @service siteSettings;
  @tracked topicSlides = [];
  @service activeSwiperInEditor;

  async loadSwiper() {
    await loadScript(settings.theme_uploads_local.swiper_js);
  }

  async loadTopicSlides() {
    const topicIds = this.args.data?.config?.topics || this.args.node?.config?.topics;
    
    if (!topicIds || !topicIds.length) {
      return;
    }

    const slides = [];
    
    for (const topicId of topicIds) {
      try {
        const response = await ajax(`/t/${topicId}.json`);
        const post = response.post_stream?.posts?.[0];
        
        if (post && post.cooked) {
          slides.push({
            type: "topic-cooked",
            topicId: topicId,
            topicTitle: response.title,
            cooked: post.cooked,
            topicSlug: response.slug,
          });
        }
      } catch (error) {
        console.error(`Failed to load topic ${topicId}:`, error);
      }
    }
    
    this.topicSlides = slides;
  }

  @action
  async destroySwiper() {
    this.mainSlider?.destroy(true, true);
    this.thumbSlider?.destroy(true, true);
  }

  @action
  didUpdateAttrs() {
    this.destroySwiper();
    this.initializeSwiper(this.swiperWrapElement);
  }

  @action
  async initializeSwiper(element) {
    this.swiperWrapElement = element;

    await this.loadSwiper();
    await this.loadTopicSlides();

    // Guard: component may have been destroyed during async operations
    if (!this.swiperWrapElement) {
      return;
    }

    if (this.config.thumbs.enabled) {
      this.thumbSlider = new window.Swiper(
        this.swiperWrapElement.querySelector(".slider-thumb"),
        {
          spaceBetween: this.config.thumbs.spaceBetween,
          direction: this.config.thumbs.direction,
          slidesPerView: this.config?.thumbs.slidesPerView,
          freeMode: true,
          watchSlidesProgress: true,
        }
      );
    }

    function hoverThumbs({ swiper, extendParams, on }) {
      extendParams({
        hoverThumbs: {
          enabled: false,
          swiper: null,
        },
      });

      on("init", function () {
        const params = swiper.params.hoverThumbs;
        if (!params.enabled || !params.swiper) {
          return;
        }

        params.swiper.slides.forEach((slide, index) => {
          slide.addEventListener("mouseenter", () => {
            swiper.slideTo(index);
          });
        });
      });

      on("destroy", function () {
        const params = swiper.params.hoverThumbs;
        if (!params.enabled || !params.swiper) {
          return;
        }

        params.swiper.slides.forEach((slide, index) => {
          slide.removeEventListener("mouseenter", () => {
            swiper.slideTo(index);
          });
        });
      });
    }

    const slideElement = this.swiperWrapElement.querySelector(".main-slider");

    this.mainSlider = new window.Swiper(slideElement, {
      enabled: true,

      direction: this.config.direction,
      slidesPerView: this.config.slidesPerView,
      slidesPerGroup: this.config.slidesPerGroup,
      centeredSlides: this.config.centeredSlides,
      spaceBetween: this.config.spaceBetween,
      grid: {
        rows: this.config.grid.rows,
      },

      autoplay: this.config.autoplay.enabled
        ? {
            delay: this.config.autoplay.delay,
            pauseOnMouseEnter: this.config.autoplay.pauseOnMouseEnter,
            disableOnInteraction: this.config.autoplay.disableOnInteraction,
            reverseDirection: this.config.autoplay.reverseDirection,
            stopOnLastSlide: this.config.autoplay.stopOnLast,
          }
        : false,

      autoHeight: this.config.autoHeight,
      //grabCursor: this.config.grabCursor,

      loop: this.config.loop,
      rewind: this.config.rewind,

      speed: this.config.speed,
      effect: this.config.effect,

      fadeEffect: {
        crossFade: this.config.crossfade,
      },

      navigation: {
        enabled: this.config.navigation.enabled,
        hideOnClick: this.config.navigation.hideOnClick,
        placement: this.config.navigation.placement,
        nextEl: this.swiperWrapElement.querySelector(".swiper-button-next"),
        prevEl: this.swiperWrapElement.querySelector(".swiper-button-prev"),
        addIcons: false,
      },

      pagination: this.config.pagination.enabled
        ? {
            clickable: this.config.pagination.clickabkle,
            type: this.config.pagination.type,
            el: this.swiperWrapElement.querySelector(".swiper-pagination"),
          }
        : false,

      keyboard: {
        enabled: this.config?.keyboard,
      },
      mousewheel: {
        invert: false,
        enabled: false,
      },

      thumbs: {
        swiper: this.config.thumbs.enabled && this.thumbSlider,
      },

      cubeEffect: {
        shadow: false,
        slideShadows: false,
        shadowOffset: 20,
        shadowScale: 0.94,
      },
      coverflowEffect: {
        rotate: 50,
        stretch: 0,
        depth: 100,
        modifier: 1,
        slideShadows: true,
      },

      // Widht/height makes swiper not responsive
      /*width: this.config?.slideWidth
          ? parseInt(this.config.slideWidth)
          : null,
        height: this.config?.slideHeight
          ? parseInt(this.config.slideHeight)
          : null,*/

      hoverThumbs: {
        enabled: this.config.thumbs.enabled && this.config.thumbs.slideOnHover,
        swiper: this.thumbSlider,
      },

      modules: [hoverThumbs],
    });

    this.activeSwiperInEditor.setTo(this.mainSlider);

    if (this.config.navigation !== null) {
      slideElement.classList.remove("swiper-navigation-disabled");

      ["inside", "outside"].forEach((placement) =>
        ["horizontal", "vertical"].forEach((direction) =>
          this.swiperWrapElement.classList.remove(
            `swiper-navigation-${placement}--${direction}`
          )
        )
      );

      if (!this.config.navigation.enabled) {
        return;
      }

      this.swiperWrapElement.classList.add(
        `swiper-navigation-${this.config.navigation.placement}--${this.config.direction}`
      );

      if (this.config.navigation.placement === "outside") {
        this.swiperWrapElement.style.setProperty(
          "--swiper-navigation-sides-offset",
          "0"
        );
      }

      if (this.config.navigation.position === "top") {
        this.swiperWrapElement.style.setProperty(
          "--swiper-navigation-top-offset",
          "10%"
        );
      } else if (this.config.navigation.position === "center") {
        this.swiperWrapElement.style.setProperty(
          "--swiper-navigation-top-offset",
          "50%"
        );
      } else if (this.config.navigation.position === "bottom") {
        this.swiperWrapElement.style.setProperty(
          "--swiper-navigation-top-offset",
          "90%"
        );
      }

      if (this.config.navigation.color) {
        this.swiperWrapElement.style.setProperty(
          "--swiper-navigation-color",
          this.config.navigation.color
        );
      }
    }

    // Post view
    if (this.data && !this.data.preview) {
      lightbox(this.swiperWrapElement, this.siteSettings);
    }

    if (this.config.mode !== "edit" && Object.keys(this.config).length > 0) {
      if (this.config.width) {
        this.swiperWrapElement.parentElement.style.width = htmlSafe(
          escapeExpression(this.config.width)
        );
      }

      if (this.config.height) {
        this.swiperWrapElement.parentElement.style.height = htmlSafe(
          escapeExpression(this.config.height)
        );

        this.swiperWrapElement.firstElementChild.style.height = htmlSafe(
          escapeExpression(this.config.height)
        );
      }
    }
  }

  @cached
  get config() {
    return normalizeSettings(
      deepMerge(
        {},
        DEFAULT_SETTINGS,
        this.args.data?.config || this.args.node?.config || {}
      )
    );
  }

  <template>
    <div
      class="swiper-wrap"
      {{didInsert this.initializeSwiper}}
      {{didInsert (if @node.onSetup @node.onSetup (noop))}}
      {{didUpdate this.didUpdateAttrs @node}}
      {{willDestroy this.destroySwiper}}
    >
      <div class="swiper main-slider">
        <div class="swiper-wrapper">
          {{#if @node.images}}
            {{#each @node.images as |node|}}
              <div class="swiper-slide">
                <img
                  draggable="false"
                  src={{node.attrs.src}}
                  alt={{node.attrs.alt}}
                  title={{node.attrs.title}}
                  width={{node.attrs.width}}
                  height={{node.attrs.height}}
                  data-orig-src={{node.attrs.originalSrc}}
                  data-scale={{node.attrs.scale}}
                  data-thumbnail={{if
                    (eq node.attrs.extras "thumbnail")
                    "true"
                  }}
                />
              </div>
            {{/each}}

          {{#each this.topicSlides as |topic|}}
            <div class="swiper-slide topic-cooked-slide" data-topic-id={{topic.topicId}}>
              <div class="topic-cooked-content">
                <h3 class="topic-cooked-title">
                  <a href="/t/{{topic.topicSlug}}/{{topic.topicId}}" target="_blank">
                    {{topic.topicTitle}}
                  </a>
                </h3>
                <div class="topic-cooked-body">
                  {{htmlSafe topic.cooked}}
                </div>
              </div>
            </div>
          {{/each}}
          {{else}}
            {{#each @data.parsedData as |data|}}
              <div class="swiper-slide">
                {{#if (eq data.type "image")}}
                  {{data.node}}
                {{/if}}
              </div>
            {{/each}}
          {{/if}}
        </div>
        {{#if
          (and
            (eq this.config.navigation.enabled true)
            (eq this.config.navigation.placement "inside")
          )
        }}
          <div class="swiper-button-next" contenteditable="false">
            <svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">
              <path d="M5.5 2.75 10.75 8 5.5 13.25"></path>
            </svg>
          </div>
          <div class="swiper-button-prev" contenteditable="false">
            <svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">
              <path d="M10.5 2.75 5.25 8l5.25 5.25"></path>
            </svg>
          </div>
        {{/if}}
        {{#if
          (and
            (eq this.config.pagination.enabled true)
            (eq this.config.pagination.placement "inside")
          )
        }}
          <div class="swiper-pagination"></div>
        {{/if}}
      </div>

      {{#if
        (and
          (eq this.config.navigation.enabled true)
          (eq this.config.navigation.placement "outside")
        )
      }}
        <div class="swiper-button-next" contenteditable="false">
          <svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">
            <path d="M5.5 2.75 10.75 8 5.5 13.25"></path>
          </svg>
        </div>
        <div class="swiper-button-prev" contenteditable="false">
          <svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">
            <path d="M10.5 2.75 5.25 8l5.25 5.25"></path>
          </svg>
        </div>
      {{/if}}

      {{#if this.config.thumbs.enabled}}
        <div
          thumbsSlider=""
          class="swiper slider-thumb --{{this.config.thumbs.direction}}"
        >
          <div class="swiper-wrapper">
            {{#if @node.images}}
              {{#each @node.images as |node|}}
                <div class="swiper-slide">
                  <img
                    draggable="false"
                    src={{node.attrs.src}}
                    alt={{node.attrs.alt}}
                    title={{node.attrs.title}}
                    width={{node.attrs.width}}
                    height={{node.attrs.height}}
                    data-orig-src={{node.attrs.originalSrc}}
                    data-scale={{node.attrs.scale}}
                    data-thumbnail={{if
                      (eq node.attrs.extras "thumbnail")
                      "true"
                    }}
                  />
                </div>
              {{/each}}

            {{else}}
              {{#each @data.parsedData as |data|}}
                <div class="swiper-slide">
                  {{data.thumbnailNode}}
                </div>
              {{/each}}
            {{/if}}
          </div>
        </div>
      {{/if}}

      {{#if
        (and
          (eq this.config.pagination.enabled true)
          (eq this.config.pagination.placement "outside")
        )
      }}
        <div class="swiper-pagination"></div>
      {{/if}}
    </div>
  </template>
}
