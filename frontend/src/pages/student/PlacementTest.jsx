import React, { useState } from "react";
import { Moon, Sun, Menu, Bot, Video, Award, BarChart3 } from "lucide-react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import { motion } from "framer-motion";

// 🔥 Mock analytics data
const analyticsData = [
  { name: "Mon", hours: 1.2 },
  { name: "Tue", hours: 2.4 },
  { name: "Wed", hours: 3.1 },
  { name: "Thu", hours: 2.2 },
  { name: "Fri", hours: 4.5 },
  { name: "Sat", hours: 3.7 },
  { name: "Sun", hours: 5.2 },
];

export default function FaangLMSDashboard() {
  const [darkMode, setDarkMode] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className={darkMode ? "dark" : ""}>
      <div className="min-h-screen bg-slate-100 dark:bg-slate-950 flex">
        {/* 📱 Mobile Sidebar */}
        <motion.div
          initial={{ x: -300 }}
          animate={{ x: sidebarOpen ? 0 : -300 }}
          className="fixed z-40 md:relative md:translate-x-0 w-64 bg-white dark:bg-slate-900 border-r border-slate-200 dark:border-slate-800 h-full"
        >
          <div className="p-6 font-bold text-xl">🚀 AI LMS</div>
          <nav className="space-y-2 px-4">
            {["Dashboard", "Courses", "AI Tutor", "Certificates"].map((item) => (
              <div
                key={item}
                className="p-3 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer text-sm font-medium"
              >
                {item}
              </div>
            ))}
          </nav>
        </motion.div>

        {/* Main Content */}
        <div className="flex-1">
          {/* Topbar */}
          <div className="flex items-center justify-between p-4 bg-white dark:bg-slate-900 border-b dark:border-slate-800">
            <div className="flex items-center gap-3">
              <Menu
                className="md:hidden cursor-pointer"
                onClick={() => setSidebarOpen(!sidebarOpen)}
              />
              <h1 className="text-xl font-semibold">Welcome back 👋</h1>
            </div>

            <button
              onClick={() => setDarkMode(!darkMode)}
              className="p-2 rounded-xl bg-slate-100 dark:bg-slate-800"
            >
              {darkMode ? <Sun size={18} /> : <Moon size={18} />}
            </button>
          </div>

          {/* Dashboard Grid */}
          <div className="p-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* 📊 Analytics Card */}
            <motion.div
              whileHover={{ scale: 1.02 }}
              className="lg:col-span-2 bg-white dark:bg-slate-900 rounded-2xl p-6 shadow-sm"
            >
              <div className="flex items-center gap-2 mb-4">
                <BarChart3 className="text-indigo-500" />
                <h2 className="font-semibold">Learning Analytics</h2>
              </div>

              <div style={{ width: "100%", height: 250 }}>
                <ResponsiveContainer>
                  <LineChart data={analyticsData}>
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Line type="monotone" dataKey="hours" strokeWidth={3} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </motion.div>

            {/* 🤖 AI Recommendations */}
            <motion.div
              whileHover={{ scale: 1.02 }}
              className="bg-gradient-to-br from-indigo-500 to-purple-600 text-white rounded-2xl p-6 shadow-sm"
            >
              <div className="flex items-center gap-2 mb-3">
                <Bot />
                <h2 className="font-semibold">AI Learning Path</h2>
              </div>

              <p className="text-sm opacity-90 mb-4">
                Based on your assessment, AI recommends:
              </p>

              <ul className="space-y-2 text-sm">
                <li>✅ Advanced React Patterns</li>
                <li>✅ System Design Basics</li>
                <li>✅ Data Structures Level 2</li>
              </ul>

              <button className="mt-5 w-full bg-white text-indigo-600 font-semibold py-2 rounded-xl">
                Start AI Path
              </button>
            </motion.div>

            {/* 🎥 Video Progress */}
            <motion.div
              whileHover={{ scale: 1.02 }}
              className="bg-white dark:bg-slate-900 rounded-2xl p-6 shadow-sm"
            >
              <div className="flex items-center gap-2 mb-3">
                <Video />
                <h2 className="font-semibold">Video Progress</h2>
              </div>

              <div className="space-y-4">
                <Progress label="React Mastery" value={75} />
                <Progress label="AI Fundamentals" value={42} />
                <Progress label="System Design" value={18} />
              </div>
            </motion.div>

            {/* 🏆 Certificate Generator */}
            <motion.div
              whileHover={{ scale: 1.02 }}
              className="bg-white dark:bg-slate-900 rounded-2xl p-6 shadow-sm"
            >
              <div className="flex items-center gap-2 mb-3">
                <Award />
                <h2 className="font-semibold">Certificates</h2>
              </div>

              <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">
                Generate verified certificates after course completion.
              </p>

              <button className="w-full bg-indigo-600 text-white py-2 rounded-xl font-semibold">
                Generate Certificate
              </button>
            </motion.div>

            {/* 💬 GPT Tutor */}
            <motion.div
              whileHover={{ scale: 1.02 }}
              className="lg:col-span-3 bg-white dark:bg-slate-900 rounded-2xl p-6 shadow-sm"
            >
              <div className="flex items-center gap-2 mb-4">
                <Bot />
                <h2 className="font-semibold">GPT Tutor Chat</h2>
              </div>

              <div className="border rounded-xl p-4 h-40 overflow-y-auto text-sm bg-slate-50 dark:bg-slate-800">
                🤖 Ask anything about your course…
              </div>

              <div className="flex gap-2 mt-3">
                <input
                  placeholder="Ask AI tutor..."
                  className="flex-1 border rounded-xl px-3 py-2 bg-transparent"
                />
                <button className="bg-indigo-600 text-white px-4 rounded-xl">
                  Send
                </button>
              </div>
            </motion.div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Progress({ label, value }) {
  return (
    <div>
      <div className="flex justify-between text-xs mb-1">
        <span>{label}</span>
        <span>{value}%</span>
      </div>
      <div className="w-full bg-slate-200 dark:bg-slate-700 h-2 rounded-full">
        <div
          className="bg-indigo-600 h-2 rounded-full"
          style={{ width: `${value}%` }}
        />
      </div>
    </div>
  );
}
