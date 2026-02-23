import DashboardLayout from "../../layouts/DashboardLayout";
import { motion } from "framer-motion";
import { Video } from "lucide-react";

export default function Courses() {
  const courses = [
    {
      id: 1,
      title: "Machine Learning",
      desc: "AI fundamentals and models"
    },
    {
      id: 2,
      title: "DevOps Mastery",
      desc: "CI/CD pipelines"
    },
    {
      id: 3,
      title: "React Pro",
      desc: "Advanced frontend"
    }
  ];

  return (
    <DashboardLayout>
      <h2 className="text-2xl font-bold mb-8">📚 My Courses</h2>

      {/* ✅ GRID FIX */}
      <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {courses.map((course) => (
          <motion.div
            key={course.id}
            whileHover={{ y: -5 }}
            className="bg-white dark:bg-slate-900 rounded-2xl p-6 shadow-sm hover:shadow-xl transition border border-gray-100 dark:border-slate-800"
          >
            <h3 className="text-lg font-semibold mb-2">
              {course.title}
            </h3>

            <p className="text-sm opacity-70 mb-6">
              {course.desc}
            </p>

            <button className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm">
              <Video size={16} />
              Start Learning
            </button>
          </motion.div>
        ))}
      </div>
    </DashboardLayout>
  );
}