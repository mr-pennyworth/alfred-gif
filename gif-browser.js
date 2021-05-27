// Negative indices for arrays
Array.prototype.get = function(i) {
  return this[(i + this.length) % this.length];
};

function isElementInViewport(el) {
  let rect = el.getBoundingClientRect();
  let right = (window.innerWidth || document.documentElement.clientWidth);

  // bottom of the viewport is covered by the footer
  // gotta account for that too.
  let bottom = (
    (window.innerHeight || document.documentElement.clientHeight)
      - document.querySelector("footer").getBoundingClientRect().height
  );

  return (
    rect.top >= 0 &&
      rect.left >= 0 &&
      rect.bottom <= bottom &&
      rect.right <= right
  );
}

function activate(elem, scroll) {
  let active = document.querySelector('.active');
  var next = elem;
  if (active == next) return;
  if (!next || !next.classList.contains('cell')) return;

  if (active) active.classList.remove('active');
  next.classList.add('active');

  // Safari doesn't support smooth scrolling
  // http://iamdustan.com/smoothscroll/
  if (scroll && !isElementInViewport(next)) {
    next.scrollIntoView({behavior: "smooth"});
  }

  document.querySelector("#caption").textContent =
    next.getAttribute("title");

  return next.getAttribute("src");
}

function findAncestorCell(elem) {
  while (elem) {
    if (elem.classList.contains('cell')) {
      return elem;
    } else {
      elem = elem.parentElement;
    }
  }
}

function activateAtCoords(x, y) {
  let elemAtCoords = document.elementFromPoint(x, y);
  return activate(findAncestorCell(elemAtCoords), false);
}

function changeActive(nextActiveFunc) {
  let active = document.querySelector('.active');
  var next = null;
  if (active) {
    next = nextActiveFunc(active);
  } else {
    // no active element, so make the first image active.
    next = document.querySelector('.cell');
  }
  return activate(next, true);
}

const prevSibling = (e) => e.previousSibling;
const nextSibling = (e) => e.nextSibling;

const iterateTillMatch = (iterFunc, matchPattern) => {
  const inner = (e) => {
    var next = iterFunc(e);
    // text nodes don't have "matches" method
    while (next && (!next.matches || !next.matches(matchPattern))) {
      next = iterFunc(next);
    }
    return next;
  };
  return inner;
};

const up = () => changeActive(iterateTillMatch(prevSibling, '.cell'));
const down = () => changeActive(iterateTillMatch(nextSibling, '.cell'));

function getAdj(node, right) {
  let nodeRect = node.getBoundingClientRect();
  let midY = nodeRect.y + nodeRect.height / 2;
  let nodeX = nodeRect.x;
  let column = node.parentElement;
  var adjCol;
  if (right) {
    adjCol = iterateTillMatch(nextSibling, '.column')(column);
  } else {
    adjCol = iterateTillMatch(prevSibling, '.column')(column);
  }
  if (!adjCol) return null;
  let allCells = [...adjCol.querySelectorAll('.cell')];
  return allCells.filter((cell) => {
    let bb = cell.getBoundingClientRect();
    return ((bb.y < midY) && (midY <= bb.y + bb.height));
  })[0];
}

const right = () => changeActive((e) => getAdj(e, true));
const left = () => changeActive((e) => getAdj(e, false));
