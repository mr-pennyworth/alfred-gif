<h1 align="center">
  
<a href="https://github.com/mr-pennyworth/alfred-gif/releases/latest/">
  <img src="icon.png" width="16%"><br/>
  <img alt="Download"
       src="https://img.shields.io/github/downloads/mr-pennyworth/alfred-gif/total?color=purple&label=Download"><br/>
</a>
  Alfred GIF Search
</h1>

Search for GIFs and animated stickers on [Tenor](https://tenor.com)
and [Giphy](https://giphy.com) from [Alfred](https://alfredapp.com).

Here's an example of searching and inserting a GIF in a google doc:
![](demo-media/alfred-gif-search-with-drag-thumbnail.gif)

Animated stickers are also GIFs, but they typically tend to have
a transparent background. Here's an example of how animated stickers look like:<br/>
![](demo-media/alfred-gif-animated-stickers.gif)

### Installation
1. Download the [latest release](https://github.com/mr-pennyworth/alfred-gif/releases/latest/download/GIF.Search.alfredworkflow).
2. In Alfred, run `.setup-gif-search`.

### Giphy Setup
- To search Giphy, you first need to [obtain a (free) API key](https://developers.giphy.com/docs/api#quick-start-guide).
- Set the API key as a [workflow variable](https://www.alfredapp.com/help/workflows/advanced/variables/#environment) named `giphy_key`.

### Usage
- In Alfred, one of the following keywords followed by search query:
  - `gif`: search Tenor for GIFs
  - `giphy`: search Giphy for GIFs
  - `sticker`: search Tenor for stickers
  - `gsticker`: search Giphy for stickers
- Press `↩`.
- Use arrow keys or mouse to browse the GIFs.
- To copy the selected GIF to clipboard:
  - either `⌘↩`
  - or `⌘-click`
- To copy the URL of selected GIF to clipboard:
  - either `⌥↩`
  - or `⌥-click`
- To drop the GIF into apps that support it:
  - drag from Alfred and drop into that app

### Note
Firefox and Chrome don't support pasting GIFs from clipboard.
That is, if you copy a GIF to clipboard and paste it, it shows
up as a static image, not an animated GIF. This is **not a bug**
in this workflow, but rather just the way these browsers have
decided to handle GIFs.

**Both Chrome and Firefox support drag-n-drop**. If you use either
of these browsers, sorry, you gotta use the mouse!
