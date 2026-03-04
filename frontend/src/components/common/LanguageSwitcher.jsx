import React from 'react';
import { useTranslation } from 'react-i18next';
import { useDispatch } from 'react-redux';
import { setLanguage } from '../../store/slices/uiSlice';
import { Globe } from 'lucide-react';

export default function LanguageSwitcher() {
  const { i18n } = useTranslation();
  const dispatch = useDispatch();

  const currentLang = i18n.language?.startsWith('mn') ? 'mn' : 'en';

  const toggleLanguage = () => {
    const newLang = currentLang === 'en' ? 'mn' : 'en';
    i18n.changeLanguage(newLang);
    dispatch(setLanguage(newLang));
    localStorage.setItem('i18nextLng', newLang);
  };

  return (
    <button
      onClick={toggleLanguage}
      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-600 hover:border-slate-500 text-slate-300 hover:text-white transition-all duration-200 text-sm font-medium"
      title={currentLang === 'en' ? 'Switch to Mongolian' : 'Switch to English'}
    >
      <Globe className="w-4 h-4" />
      <span className="font-semibold tracking-wide">
        {currentLang === 'en' ? 'EN' : 'MN'}
      </span>
      <span className="text-slate-500">|</span>
      <span className="text-slate-400 text-xs">
        {currentLang === 'en' ? 'MN' : 'EN'}
      </span>
    </button>
  );
}
