import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import { registerUser, clearError } from '../../store/slices/authSlice';
import { Eye, EyeOff, Loader2, User } from 'lucide-react';
import toast from 'react-hot-toast';

export default function RegisterPage() {
  const { t } = useTranslation();
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const { isLoading } = useSelector((state) => state.auth);

  const [form, setForm] = useState({
    firstName: '', 
    lastName: '', 
    email: '', 
    password: '', 
    confirmPassword: '', 
    role: 'student',
    agreeTerms: false,
  });
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});

  const validate = () => {
    const e = {};
    
    // First name validation
    if (!form.firstName.trim()) {
      e.firstName = t('auth.firstNameRequired', { defaultValue: 'First name is required' });
    } else if (form.firstName.trim().length < 2) {
      e.firstName = t('auth.firstNameMinLength', { defaultValue: 'First name must be at least 2 characters' });
    }
    
    // Last name validation
    if (!form.lastName.trim()) {
      e.lastName = t('auth.lastNameRequired', { defaultValue: 'Last name is required' });
    } else if (form.lastName.trim().length < 2) {
      e.lastName = t('auth.lastNameMinLength', { defaultValue: 'Last name must be at least 2 characters' });
    }
    
    // Email validation
    if (!form.email) {
      e.email = t('auth.emailRequired', { defaultValue: 'Email is required' });
    } else if (!/\S+@\S+\.\S+/.test(form.email)) {
      e.email = t('auth.invalidEmail', { defaultValue: 'Invalid email format' });
    }
    
    // Password validation
    if (!form.password) {
      e.password = t('auth.passwordRequired', { defaultValue: 'Password is required' });
    } else if (form.password.length < 8) {
      e.password = t('auth.passwordMinLength', { defaultValue: 'Password must be at least 8 characters' });
    } else if (!/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.test(form.password)) {
      e.password = t('auth.passwordStrength', { defaultValue: 'Password must contain uppercase, lowercase, and number' });
    }
    
    // Confirm password validation
    if (!form.confirmPassword) {
      e.confirmPassword = t('auth.confirmPasswordRequired', { defaultValue: 'Please confirm your password' });
    } else if (form.password !== form.confirmPassword) {
      e.confirmPassword = t('auth.passwordMismatch', { defaultValue: 'Passwords do not match' });
    }
    
    // Role validation
    if (!form.role || !['student', 'admin'].includes(form.role)) {
      e.role = t('auth.roleRequired', { defaultValue: 'Please select a role' });
    }
    
    // Terms validation
    if (!form.agreeTerms) {
      e.agreeTerms = t('auth.termsRequired', { defaultValue: 'You must agree to the terms and conditions' });
    }
    
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
      toast.success(t('auth.registerSuccess', { defaultValue: 'Registration successful!' }));
      navigate('/placement-test');
    } else {
      toast.error(result.payload || t('auth.registerFailed', { defaultValue: 'Registration failed' }));
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
        className={`w-full bg-slate-800/50 text-slate-100 placeholder-slate-400 rounded-lg px-4 py-3 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-all duration-200 ${errors[name] ? 'border-red-500 focus:ring-red-500' : 'border-slate-600/50'}`}
      />
      {errors[name] && <p className="mt-1 text-xs text-red-400">{errors[name]}</p>}
    </div>
  );

  return (
    <div className="animate-fade-in">
      <h2 className="text-3xl font-bold text-white mb-2">{t('auth.signUp', { defaultValue: 'Sign Up' })}</h2>
      <p className="text-slate-400 mb-8">
        {t('auth.hasAccount', { defaultValue: 'Already have an account?' })}{' '}
        <Link to="/login" className="text-primary-400 hover:text-primary-300 font-medium transition-colors">
          {t('auth.signIn', { defaultValue: 'Sign In' })}
        </Link>
      </p>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <Field name="firstName" label={t('auth.firstName', { defaultValue: 'First Name' })} placeholder="John" autoComplete="given-name" />
          <Field name="lastName" label={t('auth.lastName', { defaultValue: 'Last Name' })} placeholder="Doe" autoComplete="family-name" />
        </div>
        
        <Field name="email" label={t('auth.email', { defaultValue: 'Email' })} type="email" placeholder="you@example.com" autoComplete="email" />

        <div>
          <label className="block text-sm font-medium text-slate-300 mb-1.5">{t('auth.password', { defaultValue: 'Password' })}</label>
          <div className="relative">
            <input
              type={showPassword ? 'text' : 'password'}
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              placeholder="Min. 8 characters with uppercase, lowercase, and number"
              className={`w-full bg-slate-800/50 text-slate-100 placeholder-slate-400 rounded-lg px-4 py-3 pr-12 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-all duration-200 ${errors.password ? 'border-red-500 focus:ring-red-500' : 'border-slate-600/50'}`}
              autoComplete="new-password"
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

        <Field name="confirmPassword" label={t('auth.confirmPassword', { defaultValue: 'Confirm Password' })} type="password" placeholder="Repeat password" autoComplete="new-password" />

        <div>
          <label className="block text-sm font-medium text-slate-300 mb-1.5">
            <User className="inline w-4 h-4 mr-2" />
            {t('auth.role', { defaultValue: 'Role' })}
          </label>
          <select
            value={form.role}
            onChange={(e) => setForm({ ...form, role: e.target.value })}
            className={`w-full bg-slate-800/50 text-slate-100 rounded-lg px-4 py-3 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-all duration-200 ${errors.role ? 'border-red-500 focus:ring-red-500' : 'border-slate-600/50'}`}
          >
            <option value="student">{t('auth.student', { defaultValue: 'Student' })}</option>
            <option value="admin">{t('auth.admin', { defaultValue: 'Admin' })}</option>
          </select>
          {errors.role && <p className="mt-1 text-xs text-red-400">{errors.role}</p>}
        </div>

        <div>
          <label className="flex items-start gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={form.agreeTerms}
              onChange={(e) => setForm({ ...form, agreeTerms: e.target.checked })}
              className="mt-0.5 w-4 h-4 rounded border-slate-600 bg-slate-800 text-primary-500 focus:ring-primary-500 focus:outline-none"
            />
            <span className="text-sm text-slate-400">
              {t('auth.termsAgree', { defaultValue: 'I agree to the Terms of Service and Privacy Policy' })}
            </span>
          </label>
          {errors.agreeTerms && <p className="mt-1 text-xs text-red-400">{errors.agreeTerms}</p>}
        </div>

        <button 
          type="submit" 
          disabled={isLoading} 
          className="w-full bg-primary-600 hover:bg-primary-700 text-white font-semibold px-6 py-3 rounded-lg transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2 focus:ring-offset-slate-900 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
        >
          {isLoading ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              {t('common.loading', { defaultValue: 'Loading...' })}
            </>
          ) : (
            t('auth.signUp', { defaultValue: 'Sign Up' })
          )}
        </button>
      </form>
    </div>
  );
}
