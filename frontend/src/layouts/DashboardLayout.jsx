import { NavLink } from "react-router-dom";
import { useAuthStore } from "../store/useAuthStore";
import { useThemeStore } from "../store/useThemeStore";
import { Moon, Sun, Menu } from "lucide-react";
import { useState } from "react";

export default function DashboardLayout({ children }) {
  const { logout, user } = useAuthStore();
  const { darkMode, toggleTheme } = useThemeStore();
  const [open, setOpen] = useState(false);

  return (
    <div className={darkMode ? "dark" : ""}>
      <div className="flex min-h-screen">

        {/* ✅ SIDEBAR */}
        <aside
          className={`
            fixed md:static z-50 w-64 h-full
            bg-gradient-to-b from-slate-900 to-slate-950
            text-white
            transform transition-transform duration-300
            ${open ? "translate-x-0" : "-translate-x-full md:translate-x-0"}
          `}
        >
          <div className="p-6 text-xl font-bold">
            🎓 SmartLearn
          </div>

          <nav className="px-4 space-y-2">
            <NavLink className="navItemDark" to="/dashboard">
              Dashboard
            </NavLink>
            <NavLink className="navItemDark" to="/courses">
              Courses
            </NavLink>
            <NavLink className="navItemDark" to="/placement-test">
              AI Assessment
            </NavLink>
          </nav>
        </aside>

        {/* ✅ MAIN */}
        <div className="flex-1 flex flex-col">

          {/* ✅ TOP BAR (STRIPE STYLE) */}
          <header className="h-16 glass flex items-center justify-between px-6 sticky top-0 z-40">
            <div className="flex items-center gap-3">
              <button
                onClick={() => setOpen(!open)}
                className="md:hidden"
              >
                <Menu size={22} />
              </button>
              <h1 className="font-semibold text-lg">
                Welcome back 👋
              </h1>
            </div>

            <div className="flex items-center gap-4">
              <button
                onClick={toggleTheme}
                className="p-2 rounded-lg bg-gray-100 dark:bg-slate-800"
              >
                {darkMode ? <Sun size={18} /> : <Moon size={18} />}
              </button>

              <span className="text-sm opacity-70">
                {user?.name}
              </span>

              <button
                onClick={logout}
                className="bg-brand-600 hover:bg-brand-500 text-white px-4 py-2 rounded-lg text-sm font-medium transition"
              >
                Logout
              </button>
            </div>
          </header>

          {/* ✅ PAGE */}
          <main className="p-6 max-w-7xl mx-auto w-full">
            {children}
          </main>
        </div>
      </div>
    </div>
  );
}