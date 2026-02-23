import { Link } from "react-router-dom";

export default function CourseCard({ course }) {
  return (
    <div className="glass rounded-2xl p-6 shadow-soft hover:shadow-xl transition">
      <h3 className="font-semibold text-lg mb-2">{course.title}</h3>
      <p className="text-slate-500 dark:text-slate-400 mb-4">
        {course.description}
      </p>

      <Link
        to={`/player/${course.id}`}
        className="inline-block bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm"
      >
        ▶ Start Learning
      </Link>
    </div>
  );
}