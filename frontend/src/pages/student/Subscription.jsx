import React, { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import { Check, Zap, Star, Building2, Loader2 } from 'lucide-react';
import { fetchPlans, fetchCurrentSubscription, subscribeToPlan } from '../../store/slices/subscriptionSlice';
import toast from 'react-hot-toast';

const PLAN_ICONS = { free: Star, pro: Zap, enterprise: Building2 };
const PLAN_COLORS = { free: 'border-slate-600', pro: 'border-primary-500', enterprise: 'border-purple-500' };
const ICON_BG = { free: 'bg-slate-700', pro: 'bg-primary-600', enterprise: 'bg-purple-600' };

export default function SubscriptionPage() {
  const { t } = useTranslation();
  const dispatch = useDispatch();
  const { plans, currentPlan, isLoading } = useSelector((state) => state.subscription);
  const [billing, setBilling] = useState('monthly');
  const [subscribing, setSubscribing] = useState(null);

  useEffect(() => {
    dispatch(fetchPlans());
    dispatch(fetchCurrentSubscription());
  }, [dispatch]);

  const handleSubscribe = async (plan) => {
    if (plan.price_monthly === 0 || plan.price_monthly === '0.00') {
      toast.error('You are already on the free plan');
      return;
    }
    setSubscribing(plan.id);
    const result = await dispatch(subscribeToPlan({ planId: plan.id, billingCycle: billing }));
    setSubscribing(null);
    if (subscribeToPlan.fulfilled.match(result)) {
      toast.success(`Successfully subscribed to ${plan.name}!`);
    } else {
      toast.error(result.payload || 'Subscription failed');
    }
  };

  const currentPlanId = currentPlan?.plan_id || currentPlan?.id || 'free';

  const displayPlans = plans.length > 0 ? plans : [
    {
      id: 'free', name: 'Free', slug: 'free', price_monthly: 0, price_yearly: 0,
      features: ['5 free courses', 'Basic AI chat (10/day)', 'Community access', 'Course certificates'],
    },
    {
      id: 'pro', name: 'Pro', slug: 'pro', price_monthly: 29, price_yearly: 19,
      features: ['Unlimited courses', 'Unlimited AI chat', 'Offline downloads', 'Priority support', 'Advanced analytics', 'All certificates'],
    },
    {
      id: 'enterprise', name: 'Enterprise', slug: 'enterprise', price_monthly: 99, price_yearly: 79,
      features: ['Everything in Pro', 'Team management', 'Custom branding', 'SSO integration', 'Dedicated support', 'SLA guarantee', 'Custom courses', 'API access'],
    },
  ];

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

      {isLoading ? (
        <div className="flex justify-center py-16">
          <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {displayPlans.map((plan) => {
            const slug = plan.slug || plan.id;
            const Icon = PLAN_ICONS[slug] || Star;
            const price = billing === 'yearly'
              ? parseFloat(plan.price_yearly ?? plan.price_monthly ?? 0)
              : parseFloat(plan.price_monthly ?? 0);
            const isCurrent = currentPlanId === plan.id || currentPlanId === slug;
            const isPopular = slug === 'pro';
            const features = Array.isArray(plan.features)
              ? plan.features
              : (typeof plan.features === 'object' ? Object.values(plan.features).flat() : []);

            return (
              <div
                key={plan.id}
                className={`card relative flex flex-col border-2 ${PLAN_COLORS[slug] || 'border-slate-600'} ${
                  isPopular ? 'scale-105 shadow-2xl shadow-primary-500/10' : ''
                }`}
              >
                {isPopular && (
                  <div className="absolute -top-4 left-1/2 -translate-x-1/2">
                    <span className="badge bg-primary-600 text-white px-4 py-1 text-xs font-semibold">
                      {t('subscription.mostPopular')}
                    </span>
                  </div>
                )}

                <div className="flex items-center gap-3 mb-4">
                  <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${ICON_BG[slug] || 'bg-slate-700'}`}>
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
                      <span className="text-slate-400 mb-1">
                        {billing === 'monthly' ? t('subscription.perMonth') : t('subscription.perYear')}
                      </span>
                    </div>
                  )}
                </div>

                <div className="flex-1 space-y-2 mb-6">
                  {features.map((f, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-green-400 flex-shrink-0" />
                      <span className="text-sm text-slate-300">{f}</span>
                    </div>
                  ))}
                </div>

                <button
                  onClick={() => !isCurrent && handleSubscribe(plan)}
                  disabled={isCurrent || subscribing === plan.id}
                  className={`w-full py-3 rounded-xl font-semibold text-sm transition-all duration-200 flex items-center justify-center gap-2 ${
                    isCurrent
                      ? 'bg-slate-700 text-slate-400 cursor-default'
                      : isPopular
                      ? 'btn-primary'
                      : 'btn-secondary'
                  }`}
                >
                  {subscribing === plan.id && <Loader2 className="w-4 h-4 animate-spin" />}
                  {isCurrent ? t('subscription.currentPlan') : t('subscription.upgrade')}
                </button>
              </div>
            );
          })}
        </div>
      )}

      <p className="text-center text-slate-500 text-sm">{t('subscription.noCard')}</p>
    </div>
  );
}
