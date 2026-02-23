import DashboardLayout from "../../layouts/DashboardLayout";
import ProgressChart from "../../components/analytics/ProgressChart";
import AIRecommendations from "../../components/ai/AIRecommendations";

export default function Dashboard() {
  return (
    <DashboardLayout>
      {/* Stats */}
      <div className="grid md:grid-cols-3 gap-6">
        <StatCard title="Courses Enrolled" value="12" />
        <StatCard title="Hours Learned" value="48h" />
        <StatCard title="Certificates" value="5" />
      </div>

      {/* Analytics + AI */}
      <div className="grid md:grid-cols-2 gap-6 mt-6">
        <ProgressChart />
        <AIRecommendations />
      </div>
    </DashboardLayout>
  );
}

function StatCard({ title, value }) {
  return (
    <div className="bg-white rounded-2xl shadow-sm p-6 hover:shadow-md transition">
      <p className="text-slate-500 dark:text-slate-400">{title}</p>
      <h3 className="text-xl font-bold text-slate-900 dark:text-slate-100">{value}</h3>
    </div>
  );
}