// =============================================================================
// Auto Refresh Hook
// React hook for automatic UI refresh on version changes
// =============================================================================

import { useEffect, useState } from 'react';
import { getVersion, forceRefresh } from '../utils/version';

export const useAutoRefresh = (checkInterval = 5000) => {
  const [version, setVersion] = useState(getVersion());
  const [isChecking, setIsChecking] = useState(false);

  useEffect(() => {
    // Version checking is disabled
    // initVersionChecking(checkInterval);
    
    // Set up periodic version check
    const interval = setInterval(() => {
      const currentVersion = getVersion();
      if (currentVersion !== version) {
        setVersion(currentVersion);
        setIsChecking(true);
        
        // Force refresh after a short delay
        setTimeout(() => {
          forceRefresh();
        }, 1000);
      }
    }, checkInterval);

    return () => clearInterval(interval);
  }, [version, checkInterval]);

  return {
    version,
    isChecking,
    forceRefresh: () => {
      setIsChecking(true);
      setTimeout(() => forceRefresh(), 500);
    }
  };
};
