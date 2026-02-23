import { Link } from "react-router-dom";
import { useAuthStore } from "../../store/useAuthStore";

export default function Navbar() {
  const { token, logout, role } = useAuthStore();

  return (
    <div className="card" style={{ display: "flex", gap: 12 }}>
      <Link to="/dashboard">Dashboard</Link>
      <Link to="/courses">Courses</Link>

      {role === "admin" && <Link to="/admin">Admin</Link>}

      {token && (
        <button className="btn-danger" onClick={logout}>
          Logout
        </button>
      )}
    </div>
  );
}