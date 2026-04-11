import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import api from '../../services/api';

export const fetchCourses = createAsyncThunk(
  'courses/fetchAll',
  async (params = {}, { rejectWithValue }) => {
    try {
      const response = await api.get('/courses', { params });
      return response.data;
    } catch (err) {
      return rejectWithValue(err.response?.data?.message || 'Failed to fetch courses');
    }
  }
);

export const fetchCourseById = createAsyncThunk(
  'courses/fetchById',
  async (id, { rejectWithValue }) => {
    try {
      const response = await api.get(`/courses/${id}`);
      return response.data.course;
    } catch (err) {
      return rejectWithValue(err.response?.data?.message || 'Failed to fetch course');
    }
  }
);

export const enrollCourse = createAsyncThunk(
  'courses/enroll',
  async (courseId, { rejectWithValue }) => {
    try {
      const response = await api.post(`/courses/${courseId}/enroll`);
      return response.data;
    } catch (err) {
      return rejectWithValue(err.response?.data?.message || 'Failed to enroll');
    }
  }
);

export const fetchMyCourses = createAsyncThunk(
  'courses/fetchMyCourses',
  async (_, { rejectWithValue }) => {
    try {
      const response = await api.get('/courses/enrolled');
      return response.data.courses;
    } catch (err) {
      return rejectWithValue(err.response?.data?.message || 'Failed to fetch enrolled courses');
    }
  }
);

const courseSlice = createSlice({
  name: 'courses',
  initialState: {
    list: [],
    myCourses: [],
    currentCourse: null,
    total: 0,
    page: 1,
    totalPages: 1,
    isLoading: false,
    error: null,
    filters: {
      category: '',
      level: '',
      search: '',
      sortBy: 'popular',
    },
  },
  reducers: {
    setFilters: (state, action) => {
      state.filters = { ...state.filters, ...action.payload };
    },
    clearCurrentCourse: (state) => {
      state.currentCourse = null;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchCourses.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(fetchCourses.fulfilled, (state, action) => {
        state.isLoading = false;
        state.list = action.payload.courses;
        state.total = action.payload.total;
        state.page = action.payload.page;
        state.totalPages = action.payload.totalPages;
      })
      .addCase(fetchCourses.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload;
      })
      .addCase(fetchCourseById.pending, (state) => {
        state.isLoading = true;
      })
      .addCase(fetchCourseById.fulfilled, (state, action) => {
        state.isLoading = false;
        state.currentCourse = action.payload;
      })
      .addCase(fetchCourseById.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload;
      })
      .addCase(fetchMyCourses.fulfilled, (state, action) => {
        state.myCourses = action.payload;
      })
      .addCase(enrollCourse.fulfilled, (state, _action) => {
        if (state.currentCourse) {
          state.currentCourse.isEnrolled = true;
        }
      });
  },
});

export const { setFilters, clearCurrentCourse } = courseSlice.actions;
export default courseSlice.reducer;
