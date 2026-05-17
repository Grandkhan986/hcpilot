"""
Supabase Client pour HCPilot
Gestion de la connexion et des opérations de base de données
"""

import os
from typing import Optional
from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions
from dotenv import load_dotenv

load_dotenv()

class SupabaseClient:
    """Singleton Supabase client with HIPAA compliance"""
    
    _instance: Optional[Client] = None
    
    def __new__(cls):
        if cls._instance is None:
            url = os.getenv("SUPABASE_URL")
            key = os.getenv("SUPABASE_SERVICE_KEY")
            
            if not url or not key:
                raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")
            
            options = ClientOptions(
                auto_refresh_token=False,  # Géré manuellement
                persist_session=True,
                db_schema="public"
            )
            
            cls._instance = create_client(url, key, options)
            
            # Vérification de la connexion
            try:
                cls._instance.auth.get_user()
            except Exception as e:
                raise ConnectionError(f"Failed to connect to Supabase: {e}")
        
        return cls._instance
    
    @classmethod
    def get_instance(cls) -> Client:
        """Get the Supabase client instance"""
        return cls()
    
    @classmethod
    def close(cls):
        """Close the connection (for testing)"""
        cls._instance = None

# Utilisation
def get_supabase():
    """Get Supabase client"""
    return SupabaseClient.get_instance()

# Helpers pour les opérations HIPAA-compliantes
def hash_phi(data: str) -> str:
    """Hash Protected Health Information for audit logging"""
    import hashlib
    return hashlib.sha256(data.encode()).hexdigest()[:16]

def encrypt_data(data: str, key: str) -> str:
    """Encrypt sensitive data"""
    from cryptography.fernet import Fernet
    f = Fernet(key.encode())
    return f.encrypt(data.encode()).decode()

def decrypt_data(token: str, key: str) -> str:
    """Decrypt sensitive data"""
    from cryptography.fernet import Fernet
    f = Fernet(key.encode())
    return f.decrypt(token.encode()).decode()
