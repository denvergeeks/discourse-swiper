# Discourse Swiper Theme Component

A powerful and flexible Discourse theme component that integrates SwiperJS to create beautiful, touch-enabled carousels and sliders for displaying images, videos, and **topic content** directly in your Discourse posts.

## Features

### Core Functionality
- **Image & Video Slides**: Display multiple images and videos in an interactive swiper
- **Topic Content Slides**: NEW! Display cooked content from internal Discourse topics as slides
- **Multiple Effects**: Slide, fade, cube, flip, coverflow, cards, and more
- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile devices
- **Touch & Swipe Support**: Full touch gesture support with mouse wheel navigation
- **Keyboard Navigation**: Navigate slides using arrow keys
- **Thumbnail Navigation**: Optional thumbnail slider for quick slide access
- **Autoplay**: Configurable autoplay with customizable delays
- **Pagination**: Bullets, progressbar, or fraction indicators
- **Navigation Arrows**: Customizable navigation buttons

### Advanced Features
- **Nested Swipers**: Support for swipers within swipers
- **Lightbox Integration**: Built-in lightbox support for images
- **Grid Layout**: Display multiple slides per view in grid formation
- **Centered Slides**: Option to center the active slide
- **Loop Mode**: Infinite loop navigation
- **Auto Height**: Automatically adjust height based on slide content
- **Custom Styling**: Extensive CSS customization options

## Installation

1. Go to your Discourse **Admin** panel
2. Navigate to **Customize** > **Themes**
3. Click **Install** > **From a git repository**
4. Enter the repository URL: `https://github.com/denvergeeks/discourse-swiper`
5. Click **Install**

## Basic Usage

### Image Swiper

Create a swiper with images using the `[wrap=swiper]` BBCode:

```markdown
[wrap=swiper]
![Image 1](upload://abc123.jpg)
![Image 2](upload://def456.jpg)
![Image 3](upload://ghi789.jpg)
[/wrap]
```

### Topic Content Swiper (NEW!)

Display cooked content from internal topics as slides:

```markdown
[wrap=swiper topics="123,456,789"]
[/wrap]
```

Where `123`, `456`, and `789` are topic IDs. The swiper will fetch and display the first post content from each topic as a slide.

### Mixed Content Swiper

Combine images and topic content:

```markdown
[wrap=swiper topics="123,456"]
![Image 1](upload://abc123.jpg)
![Image 2](upload://def456.jpg)
[/wrap]
```

## Configuration

### Available Parameters

You can customize the swiper behavior by adding parameters to the wrap tag:

```markdown
[wrap=swiper 
  direction="horizontal"
  effect="slide"
  slidesPerView="1"
  spaceBetween="10"
  autoplay="true"
  autoplayDelay="3000"
  loop="false"
  pagination="true"
  navigation="true"
  topics="123,456,789"
]
  <!-- Your content here -->
[/wrap]
```

### Direction
- `horizontal` (default): Slides move left/right
- `vertical`: Slides move up/down

### Effects
- `slide` (default): Standard sliding transition
- `fade`: Fade in/out transition
- `cube`: 3D cube rotation effect
- `flip`: 3D flip effect
- `coverflow`: Cover flow effect (like iTunes)
- `cards`: Card-style stacking
- `creative`: Custom creative transitions

### Slides Per View
- `1` (default): Show one slide at a time
- `2`, `3`, etc.: Show multiple slides
- `auto`: Automatically determine based on slide width

### Navigation & Pagination
- `navigation="true"`: Show navigation arrows
- `navigationPlacement="inside|outside"`: Position arrows inside or outside the slider
- `navigationPosition="top|center|bottom"`: Vertical position of arrows
- `pagination="true"`: Show pagination indicators
- `paginationType="bullets|progressbar|fraction"`: Type of pagination

### Autoplay
- `autoplay="true"`: Enable autoplay
- `autoplayDelay="3000"`: Delay between slides (milliseconds)
- `autoplayPauseOnMouseEnter="true"`: Pause on hover
- `autoplayDisableOnInteraction="false"`: Continue after user interaction

### Thumbnails
- `thumbs="true"`: Enable thumbnail navigation
- `thumbsPerView="5"`: Number of thumbnails to show
- `thumbsDirection="horizontal|vertical"`: Thumbnail orientation
- `thumbsSlideOnHover="true"`: Change slide on thumbnail hover

### Advanced Options
- `loop="true"`: Enable infinite loop
- `centeredSlides="true"`: Center the active slide
- `spaceBetween="10"`: Space between slides (pixels)
- `speed="300"`: Transition speed (milliseconds)
- `keyboard="true"`: Enable keyboard navigation
- `width="100%"`: Custom width
- `height="auto"`: Custom height

## Topic Content Slides

### How It Works

1. The component fetches topic data via the Discourse API (`/t/{id}.json`)
2. Extracts the first post's cooked HTML content
3. Renders it as a slide with the topic title as a clickable link
4. Applies responsive styling for optimal readability

### Features
- **Automatic Fetching**: Topics are loaded asynchronously when the swiper initializes
- **Error Handling**: Failed topic loads are skipped silently
- **Responsive Layout**: Topic content adapts to slide dimensions
- **Styled Content**: Proper typography, spacing, and code blocks
- **Clickable Titles**: Each slide title links to the original topic

### Styling

Topic slides include:
- Scrollable content area for long posts
- Properly styled headings, lists, blockquotes
- Code block syntax highlighting
- Responsive images
- Consistent Discourse theme variables

### Security

Topics must be accessible to the viewing user. Private topics or topics from restricted categories will fail to load.

## Examples

### Simple Image Gallery

```markdown
[wrap=swiper autoplay="true" navigation="true" pagination="true"]
![Mountain](upload://mountain.jpg)
![Ocean](upload://ocean.jpg)
![Forest](upload://forest.jpg)
[/wrap]
```

### Topic Showcase with Fade Effect

```markdown
[wrap=swiper effect="fade" topics="101,102,103" autoplay="true" autoplayDelay="5000"]
[/wrap]
```

### Mixed Content Carousel

```markdown
[wrap=swiper 
  effect="coverflow"
  slidesPerView="3"
  centeredSlides="true"
  spaceBetween="30"
  topics="201,202"
]
![Banner](upload://banner.jpg)
![Promo](upload://promo.jpg)
[/wrap]
```

### Vertical Slider with Thumbnails

```markdown
[wrap=swiper 
  direction="vertical"
  thumbs="true"
  thumbsDirection="vertical"
  navigation="true"
  height="600px"
]
![Slide 1](upload://slide1.jpg)
![Slide 2](upload://slide2.jpg)
![Slide 3](upload://slide3.jpg)
[/wrap]
```

## Development

### Project Structure

```
discourse-swiper/
├── javascripts/
│   └── discourse/
│       ├── api-initializers/
│       │   └── discourse-swiper.gjs
│       ├── components/
│       │   ├── swiper-inline.gjs
│       │   ├── swiper-node-view.gjs
│       │   └── swiper-settings-panel.gjs
│       └── lib/
│           ├── constants.js
│           ├── media-element-parser.js
│           ├── rich-editor-extension.js
│           └── utils.js
├── stylesheets/
│   ├── swiper.scss
│   ├── editor.scss
│   └── settings-panel.scss
├── assets/
│   └── swiper.js (SwiperJS library)
└── locales/
    └── en.yml
```

### Key Components

- **`swiper-inline.gjs`**: Main swiper rendering component with topic fetching logic
- **`swiper-node-view.gjs`**: Composer editor integration
- **`discourse-swiper.gjs`**: API initializer for decorating cooked content
- **`media-element-parser.js`**: Parses DOM for media elements
- **`swiper.scss`**: Main styles including topic-cooked slide styles

### Building from Source

```bash
# Clone the repository
git clone https://github.com/denvergeeks/discourse-swiper.git
cd discourse-swiper

# Install dependencies
pnpm install

# Run linting
pnpm run lint

# Format code
pnpm run prettier
```

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)

## Credits

- Based on [SwiperJS](https://swiperjs.com/) v12.1.3
- Forked from [Arkshine/discourse-swiper](https://github.com/Arkshine/discourse-swiper)
- Topic cooked content feature added by denvergeeks

## License

MIT License - See [LICENSE](LICENSE) file for details

## Support

For issues, feature requests, or questions:
- Open an issue on [GitHub](https://github.com/denvergeeks/discourse-swiper/issues)
- Visit the Discourse Meta topic (link TBD)

## Changelog

### v2.0.0 (2026-03-31)
- **NEW**: Added topic cooked content slide support
- **NEW**: Fetch and display internal topic content as slides
- **NEW**: Topic slide styling with responsive layout
- Enhanced: API initializer to parse topics parameter
- Enhanced: CSS styles for topic content rendering

### v1.0.0
- Initial release
- Image and video swiper support
- Multiple transition effects
- Thumbnail navigation
- Composer integration
