import { useEffect, useState } from "react";
import api from "../../services/api";

export default function AIRecommendations() {
  const [courses, setCourses] = useState([]);

  useEffect(() => {
    api.get("/recommend").then((res) => {
      setCourses(res.data.courses || []);
    });
  }, []);

  return (
    <div className="bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm">
      <h3 className="font-semibold mb-4">🤖 AI Recommendations</h3>

      <ul className="space-y-2">
        {courses.map((c, i) => (
          <li
            key={i}
            className="p-3 rounded-lg bg-slate-100 dark:bg-slate-700"
          >
            {c}
          </li>
        ))}
      </ul>
    </div>
  );
}