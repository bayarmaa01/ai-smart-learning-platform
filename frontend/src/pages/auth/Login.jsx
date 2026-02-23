import { useAuthStore } from "../../store/useAuthStore";

export default function Login() {
  const login = useAuthStore((s) => s.login);

  return (
    <div className="min-h-screen bg-slate-100 flex items-center justify-center">
      <div className="bg-white p-10 rounded-2xl shadow-md w-96">
        <h2 className="text-2xl font-bold mb-6 text-center">
          🎓 Academic LMS
        </h2>

        <div className="space-y-4">
          <button
            onClick={() =>
              login("token", { name: "Student" }, "student")
            }
            className="w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 rounded-lg"
          >
            Login as Student
          </button>

          <button
            onClick={() =>
              login("token", { name: "Admin" }, "admin")
            }
            className="w-full bg-slate-800 hover:bg-slate-900 text-white py-3 rounded-lg"
          >
            Login as Admin
          </button>
        </div>
      </div>
    </div>
  );
}