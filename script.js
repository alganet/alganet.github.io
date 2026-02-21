(function () {
  var TRACKING_ID = 'G-087KLX3WP7';
  var THEME_KEY = 'alganet-theme';
  var root = document.documentElement;
  var prefersDark = window.matchMedia('(prefers-color-scheme: dark)');
  var isPt = window.location.pathname.indexOf('.pt') !== -1;

  var labels = isPt
    ? { theme: 'Tema', auto: 'Automático', dark: 'Escuro', light: 'Claro' }
    : { theme: 'Theme', auto: 'Auto', dark: 'Dark', light: 'Light' };

  var ICON_LAMP_ON =
    '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
    '<path d="M12 3.5a6 6 0 0 0-4.4 10.1c1 1.1 1.7 2.1 1.9 3.2h4.9c.2-1.1.9-2.1 1.9-3.2A6 6 0 0 0 12 3.5z" fill="none" stroke="currentColor" stroke-width="1.35" stroke-linejoin="round"/>' +
    '<path d="M9.4 18.2h5.2M9.9 20.2h4.2" fill="none" stroke="currentColor" stroke-width="1.35" stroke-linecap="round"/>' +
    '<path d="M12 1.7v1.4M5.3 5.3l1 1M18.7 5.3l-1 1M2.8 12h1.4M19.8 12h1.4" fill="none" stroke="currentColor" stroke-width="1.15" stroke-linecap="round"/>' +
    '</svg>';

  var ICON_LAMP_OFF =
    '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
    '<path d="M12 3.5a6 6 0 0 0-4.4 10.1c1 1.1 1.7 2.1 1.9 3.2h4.9c.2-1.1.9-2.1 1.9-3.2A6 6 0 0 0 12 3.5z" fill="none" stroke="currentColor" stroke-width="1.35" stroke-linejoin="round"/>' +
    '<path d="M9.4 18.2h5.2M9.9 20.2h4.2" fill="none" stroke="currentColor" stroke-width="1.35" stroke-linecap="round"/>' +
    '<path d="M7.2 7.1l9.6 9.8" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/>' +
    '</svg>';

  function getStoredTheme() {
    var value = window.localStorage.getItem(THEME_KEY);
    return value === 'dark' || value === 'light' ? value : null;
  }

  function getEffectiveTheme(storedTheme) {
    if (storedTheme === 'dark' || storedTheme === 'light') {
      return storedTheme;
    }
    return prefersDark.matches ? 'dark' : 'light';
  }

  function applyTheme(storedTheme) {
    var effectiveTheme = getEffectiveTheme(storedTheme);

    root.dataset.theme = effectiveTheme;
    root.dataset.themeMode = storedTheme || 'auto';

    if (storedTheme) {
      window.localStorage.setItem(THEME_KEY, storedTheme);
    } else {
      window.localStorage.removeItem(THEME_KEY);
    }
  }

  function buildThemeButton() {
    var nav = document.querySelector('nav.lang');
    if (!nav) {
      return null;
    }

    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'theme-toggle';
    nav.appendChild(button);
    return button;
  }

  function setButtonState(button) {
    var storedTheme = getStoredTheme();
    var effectiveTheme = getEffectiveTheme(storedTheme);
    var nextTheme = effectiveTheme === 'dark' ? 'light' : 'dark';
    var modeLabel = storedTheme ? labels[storedTheme] : labels.auto;

    button.innerHTML = effectiveTheme === 'light' ? ICON_LAMP_ON : ICON_LAMP_OFF;
    button.setAttribute(
      'aria-label',
      labels.theme + ': ' + modeLabel + '. Switch to ' + labels[nextTheme] + '.'
    );
    button.title = labels.theme + ': ' + modeLabel;
    button.dataset.theme = effectiveTheme;
  }

  function initThemeToggle() {
    var button = buildThemeButton();
    if (!button) {
      return;
    }

    applyTheme(getStoredTheme());
    setButtonState(button);

    button.addEventListener('click', function () {
      var currentEffective = getEffectiveTheme(getStoredTheme());
      var nextTheme = currentEffective === 'dark' ? 'light' : 'dark';

      applyTheme(nextTheme);
      setButtonState(button);
    });

    prefersDark.addEventListener('change', function () {
      if (getStoredTheme() === null) {
        applyTheme(null);
        setButtonState(button);
      }
    });
  }

  function initAnalytics() {
    var host = window.location.hostname;
    if (host === 'localhost' || host === '127.0.0.1') {
      return;
    }

    var script = document.createElement('script');
    script.async = true;
    script.src = 'https://www.googletagmanager.com/gtag/js?id=' + TRACKING_ID;
    document.head.appendChild(script);

    window.dataLayer = window.dataLayer || [];
    window.gtag = function () {
      window.dataLayer.push(arguments);
    };

    window.gtag('js', new Date());
    window.gtag('config', TRACKING_ID);
  }

  initThemeToggle();
  initAnalytics();
})();
