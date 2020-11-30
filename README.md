# Alfred GIF Search

Search GIFs on [Tenor](https://tenor.com) from [Alfred](https://alfredapp.com).

Here's an example of searching and inserting a GIF in a google doc:
![](demo-media/alfred-gif-search-with-drag-thumbnail.gif)

### Installation
1. Download the [latest release](https://github.com/mr-pennyworth/alfred-gif/releases/latest/download/GIF.Search.alfredworkflow).
2. In Alfred, run `.setup-gif-search`.

### Usage
- In Alfred, enter `gif` keyword followed by search query.
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