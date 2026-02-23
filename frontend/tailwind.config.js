/** @type {import('tailwindcss').Config} */
export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter", "ui-sans-serif", "system-ui"]
      },
      boxShadow: {
        soft: "0 10px 30px rgba(0,0,0,0.08)"
      },
      colors: {
        brand: {
          500: "#6366f1",
          600: "#4f46e5"
        }
      }
    }
  },
  plugins: []
};