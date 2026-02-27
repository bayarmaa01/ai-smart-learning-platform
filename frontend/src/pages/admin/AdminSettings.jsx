import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { Save, Globe, Shield, Bell, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '../../services/api';

export default function AdminSettings() {
  const { t } = useTranslation();
  const [settings, setSettings] = useState({
    platformName: 'EduAI Platform',
    supportEmail: 'support@eduai.com',
    maxUsersPerTenant: 10000,
    enableAIChat: true,
    enableRegistration: true,
    requireEmailVerification: true,
    maintenanceMode: false,
    defaultLanguage: 'en',
    sessionTimeout: 24,
    maxLoginAttempts: 5,
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.get('/admin/settings').then((res) => {
      if (res.data.settings) setSettings((prev) => ({ ...prev, ...res.data.settings }));
    }).catch(() => null).finally(() => setLoading(false));
  }, []);

  const handleSave = async () => {
    setSaving(true);
    try {
      await api.patch('/admin/settings', settings);
      toast.success('Settings saved successfully');
    } catch {
      toast.error('Failed to save settings');
    } finally {
      setSaving(false);
    }
  };

  const Toggle = ({ name, label, description }) => (
    <div className="flex items-center justify-between p-4 bg-slate-800/30 rounded-xl">
      <div>
        <p className="text-sm font-medium text-white">{label}</p>
        {description && <p className="text-xs text-slate-400 mt-0.5">{description}</p>}
      </div>
      <button
        onClick={() => setSettings({ ...settings, [name]: !settings[name] })}
        className={`relative w-11 h-6 rounded-full transition-colors duration-200 ${
          settings[name] ? 'bg-primary-600' : 'bg-slate-600'
        }`}
      >
        <div className={`absolute top-1 w-4 h-4 bg-white rounded-full shadow transition-transform duration-200 ${
          settings[name] ? 'translate-x-6' : 'translate-x-1'
        }`} />
      </button>
    </div>
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
      </div>
    );
  }

  const sections = [
    {
      icon: Globe, title: 'General Settings',
      content: (
        <div className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">Platform Name</label>
              <input value={settings.platformName}
                onChange={(e) => setSettings({ ...settings, platformName: e.target.value })}
                className="input-field" />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">Support Email</label>
              <input value={settings.supportEmail}
                onChange={(e) => setSettings({ ...settings, supportEmail: e.target.value })}
                className="input-field" />
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-1.5">Default Language</label>
            <select value={settings.defaultLanguage}
              onChange={(e) => setSettings({ ...settings, defaultLanguage: e.target.value })}
              className="input-field w-48">
              <option value="en">English</option>
              <option value="mn">Mongolian (Монгол)</option>
            </select>
          </div>
        </div>
      ),
    },
    {
      icon: Shield, title: 'Security Settings',
      content: (
        <div className="space-y-3">
          <Toggle name="requireEmailVerification" label="Require Email Verification"
            description="Users must verify their email before accessing the platform" />
          <Toggle name="enableRegistration" label="Allow New Registrations"
            description="Allow new users to create accounts" />
          <Toggle name="maintenanceMode" label="Maintenance Mode"
            description="Temporarily disable access for non-admin users" />
          <div className="grid grid-cols-2 gap-4 mt-4">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">Session Timeout (hours)</label>
              <input type="number" value={settings.sessionTimeout}
                onChange={(e) => setSettings({ ...settings, sessionTimeout: Number(e.target.value) })}
                className="input-field" />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">Max Login Attempts</label>
              <input type="number" value={settings.maxLoginAttempts}
                onChange={(e) => setSettings({ ...settings, maxLoginAttempts: Number(e.target.value) })}
                className="input-field" />
            </div>
          </div>
        </div>
      ),
    },
    {
      icon: Bell, title: 'Features',
      content: (
        <div className="space-y-3">
          <Toggle name="enableAIChat" label="AI Chat Assistant"
            description="Enable the multilingual AI chatbot for all users" />
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6 animate-slide-up max-w-3xl">
      <div>
        <h1 className="text-2xl font-bold text-white">{t('admin.settings')}</h1>
        <p className="text-slate-400 mt-1">Configure platform settings</p>
      </div>

      {sections.map(({ icon: Icon, title, content }) => (
        <div key={title} className="card">
          <div className="flex items-center gap-3 mb-5 pb-4 border-b border-slate-700">
            <div className="w-9 h-9 bg-primary-600/20 rounded-xl flex items-center justify-center">
              <Icon className="w-5 h-5 text-primary-400" />
            </div>
            <h2 className="text-lg font-semibold text-white">{title}</h2>
          </div>
          {content}
        </div>
      ))}

      <button onClick={handleSave} disabled={saving} className="btn-primary flex items-center gap-2">
        {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
        {t('common.save')} Settings
      </button>
    </div>
  );
}
