const { logger } = require('../utils/logger');

class SocketManager {
  constructor() {
    this.io = null;
    this.connectedUsers = new Map();
  }

  initialize(io) {
    this.io = io;
    
    io.on('connection', (socket) => {
      logger.info(`User connected: ${socket.id}`);
      
      socket.on('authenticate', (data) => {
        // Authenticate user and join appropriate rooms
        const { userId, role } = data;
        
        if (userId && role) {
          socket.userId = userId;
          socket.role = role;
          
          // Store user connection
          this.connectedUsers.set(userId, {
            socketId: socket.id,
            role: role,
            connectedAt: new Date()
          });
          
          // Join role-based rooms
          if (role === 'teacher' || role === 'admin') {
            socket.join(`instructor-${userId}`);
          }
          
          if (role === 'student') {
            socket.join(`student-${userId}`);
          }
          
          logger.info(`User ${userId} (${role}) authenticated and joined rooms`);
          
          socket.emit('authenticated', {
            success: true,
            userId: userId,
            role: role
          });
        } else {
          socket.emit('authentication-error', {
            success: false,
            message: 'Invalid authentication data'
          });
        }
      });

      socket.on('join-exam', (data) => {
        const { examId } = data;
        
        if (socket.userId && examId) {
          socket.join(`exam-${examId}`);
          logger.info(`User ${socket.userId} joined exam room: ${examId}`);
          
          socket.emit('joined-exam', {
            examId: examId,
            success: true
          });
        }
      });

      socket.on('leave-exam', (data) => {
        const { examId } = data;
        
        if (socket.userId && examId) {
          socket.leave(`exam-${examId}`);
          logger.info(`User ${socket.userId} left exam room: ${examId}`);
          
          socket.emit('left-exam', {
            examId: examId,
            success: true
          });
        }
      });

      socket.on('proctoring-event', (data) => {
        // Handle proctoring events from frontend
        const { attemptId, eventType, details } = data;
        
        if (socket.userId && attemptId && eventType) {
          logger.info(`Proctoring event from user ${socket.userId}: ${eventType} for attempt ${attemptId}`);
          
          // Broadcast to instructors monitoring this exam
          this.io.to('instructors').emit('student-proctoring-event', {
            userId: socket.userId,
            attemptId: attemptId,
            eventType: eventType,
            details: details,
            timestamp: new Date().toISOString()
          });
        }
      });

      socket.on('exam-status-request', (data) => {
        const { examId } = data;
        
        if (socket.userId && examId) {
          // Send current exam status to requesting user
          socket.emit('exam-status', {
            examId: examId,
            status: 'active',
            timestamp: new Date().toISOString()
          });
        }
      });

      socket.on('disconnect', () => {
        if (socket.userId) {
          this.connectedUsers.delete(socket.userId);
          logger.info(`User ${socket.userId} disconnected`);
        } else {
          logger.info(`Unauthenticated user disconnected: ${socket.id}`);
        }
      });

      socket.on('error', (error) => {
        logger.error(`Socket error for user ${socket.userId}:`, error);
      });
    });

    logger.info('Socket manager initialized');
  }

  // Get IO instance
  getIO() {
    return this.io;
  }

  // Send notification to specific user
  sendToUser(userId, event, data) {
    if (this.io) {
      this.io.to(`student-${userId}`).to(`instructor-${userId}`).emit(event, data);
    }
  }

  // Send notification to all instructors
  sendToInstructors(event, data) {
    if (this.io) {
      this.io.to('instructors').emit(event, data);
    }
  }

  // Send notification to exam room
  sendToExam(examId, event, data) {
    if (this.io) {
      this.io.to(`exam-${examId}`).emit(event, data);
    }
  }

  // Get connected users count
  getConnectedUsersCount() {
    return this.connectedUsers.size;
  }

  // Get user connection info
  getUserConnection(userId) {
    return this.connectedUsers.get(userId);
  }

  // Check if user is connected
  isUserConnected(userId) {
    return this.connectedUsers.has(userId);
  }
}

// Create singleton instance
const socketManager = new SocketManager();

module.exports = {
  socketManager,
  getIO: () => socketManager.getIO(),
  sendToUser: (userId, event, data) => socketManager.sendToUser(userId, event, data),
  sendToInstructors: (event, data) => socketManager.sendToInstructors(event, data),
  sendToExam: (examId, event, data) => socketManager.sendToExam(examId, event, data),
  getConnectedUsersCount: () => socketManager.getConnectedUsersCount(),
  getUserConnection: (userId) => socketManager.getUserConnection(userId),
  isUserConnected: (userId) => socketManager.isUserConnected(userId)
};
