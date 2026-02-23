import { useParams } from "react-router-dom";

export default function Player() {
  const { id } = useParams();

  return (
    <div className="container">
      <h2>Course Player</h2>
      <div className="card">Playing course ID: {id}</div>
    </div>
  );
}