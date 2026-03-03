(function (global) {
  'use strict';

  const documentRef = global.document;
  const toastContainerId = 'app-toast-container';
  const spinnerClass = 'app-loading-spinner';

  // helper ensures we always have a document before touching the dom
  function ensureDocument() {
    if (!documentRef) {
      throw new Error('ui helpers require a browser environment');
    }
  }

  // quick query selector wrapper with sane defaults
  function qs(selector, root) {
    ensureDocument();
    return (root || documentRef).querySelector(selector);
  }

  // simplified add event listener that also returns an unsubscribe helper
  function on(element, eventName, handler, options) {
    if (!element || typeof element.addEventListener !== 'function') {
      return () => {};
    }
    element.addEventListener(eventName, handler, options || false);
    return () => element.removeEventListener(eventName, handler, options || false);
  }

  // creates a toast container if it does not already exist
  function ensureToastContainer() {
    ensureDocument();
    let container = documentRef.getElementById(toastContainerId);
    if (!container) {
      container = documentRef.createElement('div');
      container.id = toastContainerId;
      container.style.position = 'fixed';
      container.style.top = '1rem';
      container.style.right = '1rem';
      container.style.zIndex = '2000';
      container.style.display = 'flex';
      container.style.flexDirection = 'column';
      container.style.gap = '0.5rem';
      documentRef.body.appendChild(container);
    }
    return container;
  }

  // lightweight toast renderer used across admin and public pages
  function toast(message, type) {
    ensureDocument();
    const container = ensureToastContainer();
    const toastElement = documentRef.createElement('div');
    toastElement.textContent = message;
    toastElement.style.padding = '0.75rem 1rem';
    toastElement.style.borderRadius = '0.5rem';
    toastElement.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)';
    toastElement.style.color = '#fff';
    toastElement.style.backgroundColor = resolveToastColor(type);
    toastElement.style.fontSize = '0.95rem';
    toastElement.style.maxWidth = '320px';
    toastElement.style.wordBreak = 'break-word';

    container.appendChild(toastElement);
    setTimeout(() => {
      toastElement.style.opacity = '0';
      toastElement.style.transition = 'opacity 250ms ease-out';
      setTimeout(() => {
        if (toastElement.parentNode) {
          toastElement.parentNode.removeChild(toastElement);
        }
      }, 300);
    }, 3500);
  }

  function resolveToastColor(type) {
    switch (type) {
      case 'success':
        return '#198754';
      case 'warning':
        return '#fd7e14';
      case 'danger':
      case 'error':
        return '#dc3545';
      default:
        return '#0d6efd';
    }
  }

  // attaches a reusable loading spinner to a container
  function showSpinner(container) {
    ensureDocument();
    if (!container) {
      return null;
    }

    const spinner = documentRef.createElement('div');
    spinner.className = spinnerClass;
    spinner.style.display = 'inline-block';
    spinner.style.width = '1.5rem';
    spinner.style.height = '1.5rem';
    spinner.style.border = '0.2rem solid rgba(0, 0, 0, 0.1)';
    spinner.style.borderTopColor = '#0d6efd';
    spinner.style.borderRadius = '50%';
    spinner.style.animation = 'app-spinner 0.9s linear infinite';

    const animation = '@keyframes app-spinner { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }';
    injectSpinnerStyle(animation);

    container.appendChild(spinner);
    return spinner;
  }

  const injectedStyles = new Set();
  function injectSpinnerStyle(rule) {
    ensureDocument();
    if (injectedStyles.has(rule)) {
      return;
    }
    const style = documentRef.createElement('style');
    style.textContent = rule;
    documentRef.head.appendChild(style);
    injectedStyles.add(rule);
  }

  // removes a spinner previously created by showSpinner
  function hideSpinner(spinner) {
    if (spinner && spinner.parentNode) {
      spinner.parentNode.removeChild(spinner);
    }
  }

  // url helper returns a single search param value
  function getParam(key) {
    if (!global.location || !global.location.search) {
      return null;
    }
    const params = new URLSearchParams(global.location.search);
    return params.get(key);
  }

  // returns all current search params as an object
  function getAllParams() {
    if (!global.location || !global.location.search) {
      return {};
    }
    const params = new URLSearchParams(global.location.search);
    const result = {};
    params.forEach((value, key) => {
      result[key] = value;
    });
    return result;
  }

  // sets or clears a single url parameter without reloading the page
  function setParam(key, value) {
    if (!global.history || !global.location) {
      return;
    }
    const params = new URLSearchParams(global.location.search);
    if (value === undefined || value === null || value === '') {
      params.delete(key);
    } else {
      params.set(key, value);
    }
    const newUrl = `${global.location.pathname}?${params.toString()}${global.location.hash}`;
    global.history.replaceState({}, '', newUrl);
  }

  const exported = {
    qs,
    on,
    toast,
    showSpinner,
    hideSpinner,
    getParam,
    getAllParams,
    setParam
  };

  global.AppUI = exported;

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = exported;
  }
})(typeof window !== 'undefined' ? window : global);
