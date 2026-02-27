import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Check, Zap, Star, Building2 } from 'lucide-react';

const plans = [
  {
    id: 'free', name: 'Free', icon: Star, price: { monthly: 0, yearly: 0 },
    color: 'border-slate-600',
    features: ['5 free courses', 'Basic AI chat (10/day)', 'Community access', 'Course certificates'],
    notIncluded: ['Unlimited courses', 'Priority AI support', 'Offline downloads', 'Team features'],
  },
  {
    id: 'pro', name: 'Pro', icon: Zap, price: { monthly: 29, yearly: 19 },
    color: 'border-primary-500', popular: true,
    features: ['Unlimited courses', 'Unlimited AI chat', 'Offline downloads', 'Priority support', 'Advanced analytics', 'All certificates'],
    notIncluded: ['Team management', 'Custom branding'],
  },
  {
    id: 'enterprise', name: 'Enterprise', icon: Building2, price: { monthly: 99, yearly: 79 },
    color: 'border-purple-500',
    features: ['Everything in Pro', 'Team management', 'Custom branding', 'SSO integration', 'Dedicated support', 'SLA guarantee', 'Custom courses', 'API access'],
    notIncluded: [],
  },
];

export default function SubscriptionPage() {
  const { t } = useTranslation();
  const [billing, setBilling] = useState('monthly');
  const currentPlan = 'free';

  return (
    <div className="space-y-8 animate-slide-up">
      <div className="text-center">
        <h1 className="text-3xl font-bold text-white mb-3">{t('subscription.title')}</h1>
        <p className="text-slate-400 max-w-xl mx-auto">{t('subscription.subtitle')}</p>
      </div>

      <div className="flex items-center justify-center">
        <div className="flex items-center gap-1 p-1 bg-slate-800 rounded-xl border border-slate-700">
          {['monthly', 'yearly'].map((b) => (
            <button
              key={b}
              onClick={() => setBilling(b)}
              className={`px-6 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                billing === b ? 'bg-primary-600 text-white' : 'text-slate-400 hover:text-white'
              }`}
            >
              {b === 'monthly' ? t('subscription.monthly') : (
                <span className="flex items-center gap-2">
                  {t('subscription.yearly')}
                  <span className="badge-green text-xs">{t('subscription.savePercent', { percent: 35 })}</span>
                </span>
              )}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {plans.map((plan) => {
          const Icon = plan.icon;
          const price = plan.price[billing];
          const isCurrent = plan.id === currentPlan;

          return (
            <div
              key={plan.id}
              className={`card relative flex flex-col border-2 ${plan.color} ${
                plan.popular ? 'scale-105 shadow-2xl shadow-primary-500/10' : ''
              }`}
            >
              {plan.popular && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2">
                  <span className="badge bg-primary-600 text-white px-4 py-1 text-xs font-semibold">
                    {t('subscription.mostPopular')}
                  </span>
                </div>
              )}

              <div className="flex items-center gap-3 mb-4">
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                  plan.id === 'free' ? 'bg-slate-700' :
                  plan.id === 'pro' ? 'bg-primary-600' : 'bg-purple-600'
                }`}>
                  <Icon className="w-5 h-5 text-white" />
                </div>
                <h3 className="text-xl font-bold text-white">{plan.name}</h3>
              </div>

              <div className="mb-6">
                {price === 0 ? (
                  <p className="text-3xl font-bold text-white">{t('subscription.free')}</p>
                ) : (
                  <div className="flex items-end gap-1">
                    <span className="text-3xl font-bold text-white">${price}</span>
                    <span className="text-slate-400 mb-1">{billing === 'monthly' ? t('subscription.perMonth') : t('subscription.perYear')}</span>
                  </div>
                )}
              </div>

              <div className="flex-1 space-y-2 mb-6">
                {plan.features.map((f) => (
                  <div key={f} className="flex items-center gap-2">
                    <Check className="w-4 h-4 text-green-400 flex-shrink-0" />
                    <span className="text-sm text-slate-300">{f}</span>
                  </div>
                ))}
                {plan.notIncluded.map((f) => (
                  <div key={f} className="flex items-center gap-2 opacity-40">
                    <div className="w-4 h-4 flex-shrink-0 flex items-center justify-center">
                      <div className="w-3 h-0.5 bg-slate-500 rounded" />
                    </div>
                    <span className="text-sm text-slate-500">{f}</span>
                  </div>
                ))}
              </div>

              <button
                className={`w-full py-3 rounded-xl font-semibold text-sm transition-all duration-200 ${
                  isCurrent
                    ? 'bg-slate-700 text-slate-400 cursor-default'
                    : plan.id === 'pro'
                    ? 'btn-primary'
                    : 'btn-secondary'
                }`}
                disabled={isCurrent}
              >
                {isCurrent ? t('subscription.currentPlan') : t('subscription.upgrade')}
              </button>
            </div>
          );
        })}
      </div>

      <p className="text-center text-slate-500 text-sm">{t('subscription.noCard')}</p>
    </div>
  );
}
