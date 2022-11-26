// JS module that imports and starts Pinput.
import * as Pinput from './pinput.js';

// Inject dependencies.
// TODO: find a way to bundle WASM into a web extension.
const buttplugCdnSrc = 'https://cdn.jsdelivr.net/npm/buttplug@1.0.16/dist/web/buttplug.min.js';
const buttplugScript = document.createElement('script');
buttplugScript.src = buttplugCdnSrc;
document.documentElement.appendChild(buttplugScript);

if (typeof chrome !== 'undefined'
    && typeof chrome.runtime !== 'undefined'
    && typeof chrome.runtime.getURL !== 'undefined') {
    /*
     * We're in a Chrome content script, and we have to inject
     * a script tag with the entire content script into the document,
     * so that it has access to the same DOM as the PICO-8 player.
     * See <https://stackoverflow.com/a/57318604>.
     */
    console.log('Pinput loader: injecting script');
    const script = document.createElement('script');
    script.src = chrome.runtime.getURL('pinput-extension.js');
    document.documentElement.appendChild(script);
} else {
	Pinput.addHapticsButton();
    Pinput.init();
}
