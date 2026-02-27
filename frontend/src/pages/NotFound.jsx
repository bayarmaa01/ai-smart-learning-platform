import React from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Home, ArrowLeft } from 'lucide-react';

export default function NotFoundPage() {
  const { t } = useTranslation();

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4">
      <div className="text-center max-w-md">
        <div className="text-8xl font-black text-slate-800 mb-4">404</div>
        <h1 className="text-2xl font-bold text-white mb-3">{t('errors.notFound')}</h1>
        <p className="text-slate-400 mb-8">{t('errors.notFoundDesc')}</p>
        <div className="flex items-center justify-center gap-4">
          <button onClick={() => window.history.back()} className="btn-secondary flex items-center gap-2">
            <ArrowLeft className="w-4 h-4" />
            {t('common.back')}
          </button>
          <Link to="/" className="btn-primary flex items-center gap-2">
            <Home className="w-4 h-4" />
            {t('errors.goHome')}
          </Link>
        </div>
      </div>
    </div>
  );
}
