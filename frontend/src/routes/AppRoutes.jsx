import { Routes, Route } from "react-router-dom";
import Login from "../pages/auth/Login";
import Dashboard from "../pages/student/Dashboard";
import Courses from "../pages/student/Courses";
import Player from "../pages/student/Player";
import AdminDashboard from "../pages/admin/AdminDashboard";
import ProtectedRoute from "../components/layout/ProtectedRoute";
import Navbar from "../components/layout/Navbar";
import PlacementTest from "../pages/student/PlacementTest";

export default function AppRoutes() {
  return (
    <>
      <Navbar />

      <Routes>
        <Route path="/" element={<Login />} />

        {/* ⭐ NEW — Placement Test */}
        <Route
          path="/placement-test"
          element={
            <ProtectedRoute>
              <PlacementTest />
            </ProtectedRoute>
          }
        />

        <Route
          path="/dashboard"
          element={
            <ProtectedRoute>
              <Dashboard />
            </ProtectedRoute>
          }
        />

        <Route
          path="/courses"
          element={
            <ProtectedRoute>
              <Courses />
            </ProtectedRoute>
          }
        />

        <Route
          path="/player/:id"
          element={
            <ProtectedRoute>
              <Player />
            </ProtectedRoute>
          }
        />

        <Route
          path="/admin"
          element={
            <ProtectedRoute role="admin">
              <AdminDashboard />
            </ProtectedRoute>
          }
        />
      </Routes>
    </>
  );
}