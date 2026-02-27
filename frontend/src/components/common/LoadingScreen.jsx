import React from 'react';
import { GraduationCap } from 'lucide-react';

export default function LoadingScreen() {
  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center">
      <div className="flex flex-col items-center gap-4">
        <div className="relative">
          <div className="w-16 h-16 bg-gradient-to-br from-primary-500 to-accent-500 rounded-2xl flex items-center justify-center animate-pulse-slow">
            <GraduationCap className="w-9 h-9 text-white" />
          </div>
          <div className="absolute -inset-1 bg-gradient-to-br from-primary-500 to-accent-500 rounded-2xl opacity-20 blur-lg animate-pulse-slow" />
        </div>
        <div className="flex gap-1.5">
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              className="w-2 h-2 bg-primary-500 rounded-full animate-bounce"
              style={{ animationDelay: `${i * 0.15}s` }}
            />
          ))}
        </div>
        <p className="text-slate-400 text-sm">Loading EduAI Platform...</p>
      </div>
    </div>
  );
}
