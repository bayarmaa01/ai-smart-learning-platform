import DashboardLayout from "../../layouts/DashboardLayout";

export default function AdminDashboard() {
  return (
    <DashboardLayout>
      <h2 className="text-2xl font-bold mb-6">👑 Admin Panel</h2>

      <div className="grid md:grid-cols-3 gap-6">
        <AdminCard title="Total Users" value="1,240" />
        <AdminCard title="Active Courses" value="32" />
        <AdminCard title="Revenue" value="$12,430" />
      </div>
    </DashboardLayout>
  );
}

function AdminCard({ title, value }) {
  return (
    <div className="bg-white rounded-2xl shadow-sm p-6">
      <p className="text-slate-500 text-sm">{title}</p>
      <h3 className="text-3xl font-bold mt-2">{value}</h3>
    </div>
  );
}