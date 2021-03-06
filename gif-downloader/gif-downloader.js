const fs = require('fs');
const http = require('http');
const https = require('https');
const path = require('path');

const {lookup} = require('lookup-dns-cache');

// https://nodejs.org/api/http.html#http_http_get_options_callback
const REQUEST_OPTS = {
  family: 4,
  lookup: lookup,
};

String.prototype.title = function() {
  return this.replace(/(^|\s)\S/g, (t) => t.toUpperCase());
};

// Negative indices for arrays
Array.prototype.get = function(i) {
  return this[(i + this.length) % this.length];
};


const CACHE_DIR = (() => {
  var cache = process.env.alfred_workflow_cache;
  if (!cache) {
    let HOME = process.env.HOME;
    cache = `${HOME}/Library/Caches/com.runningwithcrayons.Alfred` +
      '/Workflow Data/mr.pennyworth.gif/';
  }
  if (!fs.existsSync(cache)) {
    fs.mkdirSync(cache, { recursive: true });
  }

  let runtimeAssets = [
    'gif-browser.css',
    'gif-navigator.js',
    'smoothscroll.js',
  ];

  runtimeAssets.forEach((asset) => {
    let src = path.join(__dirname, asset);
    let dest = path.join(cache, asset);
    if (!fs.existsSync(dest)) {
      // need to read then write as copyFileSync doesn't work
      // with pkg's snapshot filesystem
      // https://github.com/vercel/pkg/issues/420
      fs.writeFileSync(dest, fs.readFileSync(src));
    }
  });

  return cache;
})();


function makeHtml(gifInfos) {
  const N_COLS = 3;
  let cols = [];
  for (let i = 0; i < N_COLS; i++) {
    cols.push([]);
    // because the footer might hide the bottom gifs partly,
    // for each column, add one extra gif at the bottom.
    gifInfos.push(gifInfos[i]);
  }

  gifInfos.forEach((gif, i) => {
    let markup = `<img class="cell" src="${gif.url}" title="${gif.title}">`;
    cols[i % N_COLS].push(markup);
  });

  let grid = cols.map((col) =>
    `<div class="column">${col.join('')}</div>`
  ).join('');

  return `
    <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <script type="text/javascript" src="smoothscroll.js"></script>
        <script type="text/javascript" src="gif-navigator.js"></script>
        <link rel="stylesheet" href="gif-browser.css">
      </head>
      <body>
        ${grid}
        <footer>
          <span id="caption"></span>
          <span id="credits">Powered by Tenor</span>
        </footer>
      </body>
    </html>`;
}

function makeAlfredResponse(htmlPath) {
  return {
    'items': [{
      'arg': 'dummy',
      'valid': true,
      'title': 'Select with arrow keys, drag-n-drop with mouse',
      'subtitle':
      '[↩: search again] [⌘: copy GIF] [⌥: copy URL]',
      'quicklookurl': htmlPath
    }]
  };
}

function parseTenorData(tenorData, query) {
  let htmlName =
    query
      .toLowerCase()
      .replace(/[^0-9a-z ]/gi, '')
      .replace(' ', '-');
  let htmlPath = `${CACHE_DIR}/${htmlName}.html`;

  let gifInfos = tenorData.results.map((tenorEntry) => {
    // Example tinygif url:
    // https://c.tenor.com/-bHlmkHiqoQAAAAM/harry-potter-dobby.gif
    let gifUrl = tenorEntry.media_formats.tinygif.url;
    let gifHash = gifUrl.split('/').get(-2);
    let gifPath = `${CACHE_DIR}/${gifHash}.gif`;

    // Example itemurl: https://tenor.com/view/freaking-out-kermit-gif-8832122
    // Title we want  : Freaking Out Kermit
    let title =
      decodeURI(tenorEntry.itemurl)
        .split('/')[4]
        .split('-').slice(0, -2)
        .join(' ')
        .title();

    return {
      'url': gifUrl,
      'path': gifPath,
      'title': title
    };
  });

  fs.exists(htmlPath, (exists) => {
    if (!exists) {
      fs.writeFile(
        htmlPath,
        makeHtml(gifInfos),
        (err) => { 
          if (err) {
            console.error(err); 
          } else {
            console.log(`Created ${htmlPath}`);
          }
        }
      );
    } else {
      console.log(`${htmlPath} already cached`);
    }
  });

  return {
    'gifs': gifInfos,
    'alfredResponse': makeAlfredResponse(htmlPath)
  };
}


async function downloadGifs(gifs) {
  gifs.forEach((gif) => {
    fs.exists(gif.path, (exists) => {
      if (!exists) {
        const stream = fs.createWriteStream(gif.path);
        const getter = gif.url.startsWith('https:') ? https : http;
        getter.get(gif.url, REQUEST_OPTS, (response) => {
          console.log(`Downloading ${gif.url}`);
          response.pipe(stream);
        });
      } else {
        console.log(`${gif.url} already downloaded`);
      }
    });
  });
}


http.createServer(function (req, res) {
  let url = new URL(req.url, `http://${req.headers.host}`);
  let query = url.searchParams.get('query');

  let cachedHtmlName = `${query.toLowerCase().split(" ").join("-")}-gifs.html`;
  let cachedHtmlPath = `${CACHE_DIR}/${cachedHtmlName}`;

  if (fs.existsSync(cachedHtmlPath)) {
    res.write(JSON.stringify(makeAlfredResponse(cachedHtmlPath)));
    res.end();
    console.log('Responded to alfred from cache');
    res = {
      'write': (_) => {},
      'end': () => {}
    };
    // we might have the cached html but still, maybe last time,
    // not all GIFs were downloaded. Hence, we don't just return here.
  }

  let tenorUrl = new URL('https://tenor.googleapis.com/v2/search');
  tenorUrl.searchParams.append('q', query);
  tenorUrl.searchParams.append('limit', '50');
  tenorUrl.searchParams.append('key', 'AIzaSyAyimkuYQYF_FXVALexPuGQctUWRURdCYQ');
  tenorUrl.searchParams.append('client_key', 'gboard');
  tenorUrl.searchParams.append('media_filter', 'tinygif');

  https.get(tenorUrl, REQUEST_OPTS, (tenorRes) => {
    const { statusCode } = tenorRes;
    const contentType = tenorRes.headers['content-type'];

    let error;
    // Any 2xx status code signals a successful response but
    // here we're only checking for 200.
    if (statusCode !== 200) {
      error = new Error(
        `Request Failed.\nStatus Code: ${statusCode}`
      );
    } else if (!/^application\/json/.test(contentType)) {
      error = new Error(
        'Invalid content-type.\n' +
          `Expected application/json but received ${contentType}`
      );
    }

    if (error) {
      console.error(error.message);

      // Consume response data to free up memory
      tenorRes.resume();

      res.write(error.message);
      res.end();
      return;
    }

    tenorRes.setEncoding('utf8');
    let rawData = '';
    tenorRes.on('data', (chunk) => { rawData += chunk; });
    tenorRes.on('end', () => {
      try {
        const tenorData = JSON.parse(rawData);
        const parsed = parseTenorData(tenorData, query);
        res.write(JSON.stringify(parsed.alfredResponse));
        res.end();
        console.log('Responded to alfred');
        downloadGifs(parsed.gifs);
      } catch (e) {
        console.error(e.message);
        res.write(e.message);
        res.end();
      }
    });
  }).on('error', (e) => {
    console.error(`Got error: ${e.message}`);
    res.write(e.message);
    res.end();
  });

  console.log(url.searchParams);
}).listen(8910);
