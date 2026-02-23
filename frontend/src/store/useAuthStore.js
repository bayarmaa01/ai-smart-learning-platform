import { create } from "zustand";

export const useAuthStore = create((set) => ({
  user: null,
  token: localStorage.getItem("token"),
  role: localStorage.getItem("role"),

  login: (token, user, role) => {
    localStorage.setItem("token", token);
    localStorage.setItem("role", role);
    set({ token, user, role });
  },

  logout: () => {
    localStorage.clear();
    set({ token: null, user: null, role: null });
  }
}));