import { useTranslation } from "react-i18next";

function App() {
  const { t, i18n } = useTranslation();

  return (
    <div>
      <button onClick={() => i18n.changeLanguage("en")}>EN</button>
      <button onClick={() => i18n.changeLanguage("mn")}>MN</button>
      <h1>{t("welcome")}</h1>
    </div>
  );
}

export default App;
