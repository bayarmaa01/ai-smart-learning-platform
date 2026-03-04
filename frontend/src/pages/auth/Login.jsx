import React, { useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import { loginUser, clearError } from '../../store/slices/authSlice';
import { Eye, EyeOff, GraduationCap, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';

export default function LoginPage() {
  const { t } = useTranslation();
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const location = useLocation();
  const { isLoading, error } = useSelector((state) => state.auth);

  const [form, setForm] = useState({ email: '', password: '' });
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});

  const from = location.state?.from?.pathname || '/dashboard';

  const validate = () => {
    const newErrors = {};
    if (!form.email) newErrors.email = t('auth.emailRequired');
    else if (!/\S+@\S+\.\S+/.test(form.email)) newErrors.email = t('auth.invalidEmail');
    if (!form.password) newErrors.password = t('auth.passwordRequired');
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    dispatch(clearError());
    if (!validate()) return;

    const result = await dispatch(loginUser(form));
    if (loginUser.fulfilled.match(result)) {
      toast.success(t('auth.loginSuccess'));
      navigate(from, { replace: true });
    } else {
      toast.error(result.payload || t('auth.loginError'));
    }
  };

  return (
    <div className="animate-fade-in">
      <div className="flex items-center gap-3 mb-8 lg:hidden">
        <div className="w-10 h-10 bg-primary-500 rounded-xl flex items-center justify-center">
          <GraduationCap className="w-6 h-6 text-white" />
        </div>
        <span className="text-xl font-bold text-white">EduAI Platform</span>
      </div>

      <h2 className="text-3xl font-bold text-white mb-2">{t('auth.signIn')}</h2>
      <p className="text-slate-400 mb-8">
        {t('auth.noAccount')}{' '}
        <Link to="/register" className="text-primary-400 hover:text-primary-300 font-medium transition-colors">
          {t('auth.signUp')}
        </Link>
      </p>

      <form onSubmit={handleSubmit} className="space-y-5">
        <div>
          <label className="block text-sm font-medium text-slate-300 mb-1.5">
            {t('auth.email')}
          </label>
          <input
            type="email"
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
            placeholder="you@example.com"
            className={`input-field ${errors.email ? 'border-red-500 focus:ring-red-500' : ''}`}
            autoComplete="email"
          />
          {errors.email && <p className="mt-1 text-xs text-red-400">{errors.email}</p>}
        </div>

        <div>
          <div className="flex items-center justify-between mb-1.5">
            <label className="block text-sm font-medium text-slate-300">
              {t('auth.password')}
            </label>
            <Link to="/forgot-password" className="text-xs text-primary-400 hover:text-primary-300 transition-colors">
              {t('auth.forgotPassword')}
            </Link>
          </div>
          <div className="relative">
            <input
              type={showPassword ? 'text' : 'password'}
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              placeholder="••••••••"
              className={`input-field pr-12 ${errors.password ? 'border-red-500 focus:ring-red-500' : ''}`}
              autoComplete="current-password"
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-300 transition-colors"
            >
              {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
            </button>
          </div>
          {errors.password && <p className="mt-1 text-xs text-red-400">{errors.password}</p>}
        </div>

        <button
          type="submit"
          disabled={isLoading}
          className="btn-primary w-full flex items-center justify-center gap-2"
        >
          {isLoading ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              {t('common.loading')}
            </>
          ) : (
            t('auth.signIn')
          )}
        </button>
      </form>

      <div className="mt-6">
        <div className="relative">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-slate-700" />
          </div>
          <div className="relative flex justify-center text-sm">
            <span className="px-3 bg-slate-950 text-slate-400">{t('common.or')}</span>
          </div>
        </div>
        <div className="mt-4 p-4 bg-slate-800/50 rounded-xl border border-slate-700">
          <p className="text-xs text-slate-400 text-center mb-2">Demo Credentials</p>
          <div className="grid grid-cols-2 gap-2 text-xs">
            <button
              type="button"
              onClick={() => setForm({ email: 'student@demo.com', password: 'Demo@1234' })}
              className="p-2 bg-slate-700 hover:bg-slate-600 rounded-lg text-slate-300 transition-colors text-center"
            >
              Student Demo
            </button>
            <button
              type="button"
              onClick={() => setForm({ email: 'admin@demo.com', password: 'Admin@1234' })}
              className="p-2 bg-slate-700 hover:bg-slate-600 rounded-lg text-slate-300 transition-colors text-center"
            >
              Admin Demo
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
