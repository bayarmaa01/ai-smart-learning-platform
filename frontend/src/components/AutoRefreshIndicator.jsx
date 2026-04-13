// =============================================================================
// Auto Refresh Indicator Component
// Shows when auto-refresh is checking or updating
// =============================================================================

import React from 'react';
import { RefreshCw, AlertCircle } from 'lucide-react';

const AutoRefreshIndicator = ({ isChecking, version, onForceRefresh }) => {
  return (
    <div className="fixed bottom-4 right-4 z-50 flex items-center gap-2 bg-white rounded-lg shadow-lg p-3 border border-gray-200">
      {isChecking ? (
        <>
          <RefreshCw className="w-4 h-4 animate-spin text-blue-600" />
          <span className="text-sm text-gray-600">Updating...</span>
        </>
      ) : (
        <>
          <div className="w-2 h-2 bg-green-500 rounded-full" title="Live" />
          <span className="text-xs text-gray-500">v{version}</span>
          <button
            onClick={onForceRefresh}
            className="ml-2 p-1 hover:bg-gray-100 rounded transition-colors"
            title="Force refresh"
          >
            <RefreshCw className="w-3 h-3 text-gray-500 hover:text-gray-700" />
          </button>
        </>
      )}
    </div>
  );
};

export default AutoRefreshIndicator;
