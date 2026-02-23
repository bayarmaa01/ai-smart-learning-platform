import { create } from "zustand";

export const useThemeStore = create((set) => ({
  darkMode: false,

  toggleTheme: () =>
    set((state) => ({
      darkMode: !state.darkMode
    }))
}));