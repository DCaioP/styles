// ==UserScript==
// @name         New Userscript
// @namespace    http://tampermonkey.net/
// @version      2025-06-12
// @description  try to take over the world!
// @author       You
// @match        https://kromosproducoes180522.protheus.cloudtotvs.com.br:2253/webapp/
// @icon         https://www.google.com/s2/favicons?sz=64&domain=cloudtotvs.com.br
// @grant        none
// ==/UserScript==

(function () {
    var css = `
        body.firefox{
            color: red !important;
        }
        /* transparency */
        body, #app, .app-root, wa-dialog {
            background: none !important;
            background-color: transparent !important;
            border: none !important;
            box-shadow: none !important;
        }

        /* garante que QUALQUER var branca fique 100 % transparente */
        :root{
            --color-neutral-light-00: rgba(0,0,0,0) !important;
            --color-wrapper-menu-panel-color-background: rgba(0,0,0,0) !important;
            --color-overlay-background-color-overlay: rgba(0,0,0,0) !important;
            --wa-dialog-background-color: transparent !important;
        }

        /* se o script colar branco inline */
        body[style], [style*="background"] {
            background: none !important;
        }
    `;
    var style = document.createElement('style');
    style.textContent = css;
    document.head.appendChild(style);
})();
