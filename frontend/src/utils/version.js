// =============================================================================
// Auto Versioning Utility
// Handles automatic UI versioning and cache busting
// =============================================================================

// Get stable build version (Vite env)
const getVersion = () => {
  return (
    import.meta.env.VITE_APP_VERSION ||
    import.meta.env.VITE_BUILD_TIME ||
    '1.0.0'
  );
};

// Generate cache-busting query string
const getCacheBuster = () => {
  const version = getVersion();
  return `?v=${version}`;
};

// Add cache busting to URLs
const addVersionToUrl = (url) => {
  if (!url) return url;
  
  // Skip external URLs and data URLs
  if (url.startsWith('http') || url.startsWith('data:')) {
    return url;
  }
  
  const separator = url.includes('?') ? '&' : '?';
  return `${url}${separator}v=${getVersion()}`;
};

// Force UI refresh
const forceRefresh = () => {
  const timestamp = Date.now();
  localStorage.setItem('app-version', timestamp);
  window.location.reload();
};

// Get build info
const getBuildInfo = () => {
  return {
    version: getVersion(),
    buildTime: import.meta.env.VITE_BUILD_TIME || 'unknown',
    environment: import.meta.env.MODE || 'development',
    cacheBuster: getCacheBuster()
  };
};

export {
  getVersion,
  getCacheBuster,
  addVersionToUrl,
  initVersionChecking,
  forceRefresh,
  getBuildInfo
};
