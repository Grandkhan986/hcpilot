import { describe, it, expect, beforeEach } from 'vitest';
import { useAuthStore } from '../../stores/auth';

describe('useAuthStore', () => {
  beforeEach(() => {
    useAuthStore.setState({
      user: null,
      token: null,
      isAuthenticated: false,
    });
  });

  it('should start with unauthenticated state', () => {
    const state = useAuthStore.getState();
    expect(state.isAuthenticated).toBe(false);
    expect(state.user).toBeNull();
    expect(state.token).toBeNull();
  });

  it('should login successfully', () => {
    const mockUser = {
      id: '1',
      email: 'doctor@test.com',
      full_name: 'Dr. Test',
      role: 'provider',
      created_at: '2024-01-01T00:00:00Z',
    };

    useAuthStore.getState().login('test-token', mockUser);

    const state = useAuthStore.getState();
    expect(state.isAuthenticated).toBe(true);
    expect(state.token).toBe('test-token');
    expect(state.user?.email).toBe('doctor@test.com');
  });

  it('should logout successfully', () => {
    const mockUser = {
      id: '1',
      email: 'doctor@test.com',
      full_name: 'Dr. Test',
      role: 'provider',
      created_at: '2024-01-01T00:00:00Z',
    };

    useAuthStore.getState().login('test-token', mockUser);
    useAuthStore.getState().logout();

    const state = useAuthStore.getState();
    expect(state.isAuthenticated).toBe(false);
    expect(state.user).toBeNull();
    expect(state.token).toBeNull();
  });

  it('should update profile', () => {
    const mockUser = {
      id: '1',
      email: 'doctor@test.com',
      full_name: 'Dr. Test',
      role: 'provider',
      created_at: '2024-01-01T00:00:00Z',
    };

    useAuthStore.getState().login('test-token', mockUser);
    useAuthStore.getState().updateProfile({ specialty: 'Cardiology' });

    const state = useAuthStore.getState();
    expect(state.user?.specialty).toBe('Cardiology');
    expect(state.user?.full_name).toBe('Dr. Test');
  });
});
