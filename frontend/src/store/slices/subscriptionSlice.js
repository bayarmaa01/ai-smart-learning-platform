import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import api from '../../services/api';

export const fetchPlans = createAsyncThunk('subscription/fetchPlans', async (_, { rejectWithValue }) => {
  try {
    const response = await api.get('/subscriptions/plans');
    return response.data.plans;
  } catch (err) {
    return rejectWithValue(err.response?.data?.message || 'Failed to fetch plans');
  }
});

export const fetchCurrentSubscription = createAsyncThunk(
  'subscription/fetchCurrent',
  async (_, { rejectWithValue }) => {
    try {
      const response = await api.get('/subscriptions/current');
      return response.data.subscription;
    } catch (err) {
      return rejectWithValue(err.response?.data?.message || 'Failed to fetch subscription');
    }
  }
);

export const subscribeToPlan = createAsyncThunk(
  'subscription/subscribe',
  async ({ planId, billingCycle }, { rejectWithValue }) => {
    try {
      const response = await api.post('/subscriptions/subscribe', { planId, billingCycle });
      return response.data;
    } catch (err) {
      return rejectWithValue(err.response?.data?.message || 'Failed to subscribe');
    }
  }
);

const subscriptionSlice = createSlice({
  name: 'subscription',
  initialState: {
    plans: [],
    currentPlan: null,
    isLoading: false,
    error: null,
  },
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(fetchPlans.pending, (state) => { state.isLoading = true; })
      .addCase(fetchPlans.fulfilled, (state, action) => {
        state.isLoading = false;
        state.plans = action.payload;
      })
      .addCase(fetchPlans.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload;
      })
      .addCase(fetchCurrentSubscription.pending, (state) => { state.isLoading = true; })
      .addCase(fetchCurrentSubscription.fulfilled, (state, action) => {
        state.isLoading = false;
        state.currentPlan = action.payload;
      })
      .addCase(fetchCurrentSubscription.rejected, (state) => { state.isLoading = false; })
      .addCase(subscribeToPlan.fulfilled, (state, action) => {
        state.currentPlan = action.payload.subscription;
      });
  },
});

export default subscriptionSlice.reducer;
