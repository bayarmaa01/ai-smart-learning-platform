import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import api from '../../services/api';

export const sendMessage = createAsyncThunk(
  'chat/sendMessage',
  async ({ message, sessionId }, { rejectWithValue }) => {
    try {
      const response = await api.post('/ai/chat', { message });
      return response.data;
    } catch (err) {
      return rejectWithValue(err.response?.data?.error || 'AI service unavailable');
    }
  }
);

export const fetchChatHistory = createAsyncThunk(
  'chat/fetchHistory',
  async (sessionId, { rejectWithValue }) => {
    try {
      const response = await api.get(`/ai/chat/history/${sessionId}`);
      return response.data.messages;
    } catch (err) {
      return rejectWithValue(err.response?.data?.message || 'Failed to fetch history');
    }
  }
);

const chatSlice = createSlice({
  name: 'chat',
  initialState: {
    messages: [],
    sessionId: null,
    isTyping: false,
    error: null,
    detectedLanguage: 'en',
  },
  reducers: {
    addUserMessage: (state, action) => {
      state.messages.push({
        id: Date.now().toString(),
        role: 'user',
        content: action.payload.content,
        timestamp: new Date().toISOString(),
      });
    },
    setSessionId: (state, action) => {
      state.sessionId = action.payload;
    },
    clearChat: (state) => {
      state.messages = [];
      state.sessionId = null;
      state.error = null;
    },
    setDetectedLanguage: (state, action) => {
      state.detectedLanguage = action.payload;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(sendMessage.pending, (state) => {
        state.isTyping = true;
        state.error = null;
      })
      .addCase(sendMessage.fulfilled, (state, action) => {
        state.isTyping = false;
        if (action.payload.success && action.payload.data) {
          state.messages.push({
            id: Date.now().toString(),
            role: 'assistant',
            content: action.payload.data.response,
            timestamp: new Date().toISOString(),
            detectedLanguage: 'en',
            sources: [],
          });
        }
      })
      .addCase(sendMessage.rejected, (state, action) => {
        state.isTyping = false;
        state.error = action.payload;
        state.messages.push({
          id: Date.now().toString(),
          role: 'assistant',
          content: 'Sorry, I encountered an error. Please try again. / Уучлаарай, алдаа гарлаа. Дахин оролдоно уу.',
          timestamp: new Date().toISOString(),
          isError: true,
        });
      })
      .addCase(fetchChatHistory.fulfilled, (state, action) => {
        state.messages = action.payload;
      });
  },
});

export const { addUserMessage, setSessionId, clearChat, setDetectedLanguage } = chatSlice.actions;
export default chatSlice.reducer;
