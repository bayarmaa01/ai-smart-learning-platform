import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import { registerUser, clearError } from '../../store/slices/authSlice';
import { Eye, EyeOff, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';

export default function RegisterPage() {
  const { t } = useTranslation();
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const { isLoading } = useSelector((state) => state.auth);

  const [form, setForm] = useState({
    firstName: '', lastName: '', email: '', password: '', confirmPassword: '', agreeTerms: false,
  });
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});

  const validate = () => {
    const e = {};
    if (!form.firstName.trim()) e.firstName = t('auth.emailRequired').replace('Email', 'First name');
    if (!form.lastName.trim()) e.lastName = t('auth.emailRequired').replace('Email', 'Last name');
    if (!form.email) e.email = t('auth.emailRequired');
    else if (!/\S+@\S+\.\S+/.test(form.email)) e.email = t('auth.invalidEmail');
    if (!form.password) e.password = t('auth.passwordRequired');
    else if (form.password.length < 8) e.password = t('auth.passwordMinLength');
    if (form.password !== form.confirmPassword) e.confirmPassword = t('auth.passwordMismatch');
    if (!form.agreeTerms) e.agreeTerms = t('auth.termsRequired');
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    dispatch(clearError());
    if (!validate()) return;

    const { confirmPassword, agreeTerms, ...userData } = form;
    const result = await dispatch(registerUser(userData));
    if (registerUser.fulfilled.match(result)) {
      toast.success(t('auth.registerSuccess'));
      navigate('/placement-test');
    } else {
      toast.error(result.payload || 'Registration failed');
    }
  };

  const Field = ({ name, label, type = 'text', placeholder, autoComplete }) => (
    <div>
      <label className="block text-sm font-medium text-slate-300 mb-1.5">{label}</label>
      <input
        type={type}
        value={form[name]}
        onChange={(e) => setForm({ ...form, [name]: e.target.value })}
        placeholder={placeholder}
        autoComplete={autoComplete}
        className={`input-field ${errors[name] ? 'border-red-500 focus:ring-red-500' : ''}`}
      />
      {errors[name] && <p className="mt-1 text-xs text-red-400">{errors[name]}</p>}
    </div>
  );

  return (
    <div className="animate-fade-in">
      <h2 className="text-3xl font-bold text-white mb-2">{t('auth.signUp')}</h2>
      <p className="text-slate-400 mb-8">
        {t('auth.hasAccount')}{' '}
        <Link to="/login" className="text-primary-400 hover:text-primary-300 font-medium transition-colors">
          {t('auth.signIn')}
        </Link>
      </p>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <Field name="firstName" label={t('auth.firstName')} placeholder="John" autoComplete="given-name" />
          <Field name="lastName" label={t('auth.lastName')} placeholder="Doe" autoComplete="family-name" />
        </div>
        <Field name="email" label={t('auth.email')} type="email" placeholder="you@example.com" autoComplete="email" />

        <div>
          <label className="block text-sm font-medium text-slate-300 mb-1.5">{t('auth.password')}</label>
          <div className="relative">
            <input
              type={showPassword ? 'text' : 'password'}
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              placeholder="Min. 8 characters"
              className={`input-field pr-12 ${errors.password ? 'border-red-500 focus:ring-red-500' : ''}`}
              autoComplete="new-password"
            />
            <button type="button" onClick={() => setShowPassword(!showPassword)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-300">
              {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
            </button>
          </div>
          {errors.password && <p className="mt-1 text-xs text-red-400">{errors.password}</p>}
        </div>

        <Field name="confirmPassword" label={t('auth.confirmPassword')} type="password" placeholder="Repeat password" autoComplete="new-password" />

        <div>
          <label className="flex items-start gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={form.agreeTerms}
              onChange={(e) => setForm({ ...form, agreeTerms: e.target.checked })}
              className="mt-0.5 w-4 h-4 rounded border-slate-600 bg-slate-800 text-primary-500 focus:ring-primary-500"
            />
            <span className="text-sm text-slate-400">{t('auth.termsAgree')}</span>
          </label>
          {errors.agreeTerms && <p className="mt-1 text-xs text-red-400">{errors.agreeTerms}</p>}
        </div>

        <button type="submit" disabled={isLoading} className="btn-primary w-full flex items-center justify-center gap-2">
          {isLoading ? (
            <><Loader2 className="w-4 h-4 animate-spin" />{t('common.loading')}</>
          ) : t('auth.signUp')}
        </button>
      </form>
    </div>
  );
}
