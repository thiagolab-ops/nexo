import firebase_admin
from firebase_admin import credentials, firestore

# --- CONFIGURAÇÃO ---
cred = credentials.Certificate("scripts/serviceAccountKey.json")
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()
print("Conectado ao projeto Firebase com sucesso.")
# --- FIM DA CONFIGURAÇÃO ---

def migrate_users():
    """
    Este script percorre todos os documentos na coleção 'users'.
    Para cada usuário, ele verifica se o campo 'hasCompletedOnboarding' existe.
    Se não existir, ele o adiciona com o valor 'true'.
    """
    users_ref = db.collection('users')
    all_users = users_ref.stream()
    
    batch = db.batch()
    updated_count = 0
    checked_count = 0
    
    print("Iniciando a verificação dos usuários...")

    for user_doc in all_users:
        checked_count += 1
        user_data = user_doc.to_dict()
        
        if 'hasCompletedOnboarding' not in user_data:
            print(f"  -> Usuário {user_doc.id} ({user_data.get('username', 'N/A')}) será atualizado.")
            
            # CORREÇÃO: O método correto é .document(), não .doc()
            user_ref = users_ref.document(user_doc.id) 
            batch.update(user_ref, {'hasCompletedOnboarding': True})
            updated_count += 1
            
            if updated_count > 0 and updated_count % 499 == 0:
                print(f"\n--- Lote de {updated_count} atualizações atingido, enviando para o Firestore... ---\n")
                batch.commit()
                batch = db.batch()

    if updated_count > 0:
        print("\nEnviando o lote final...")
        batch.commit()
        print("Lote final enviado com sucesso!")
    
    print("\n--- Migração Concluída ---")
    print(f"Total de usuários verificados: {checked_count}")
    print(f"Total de usuários atualizados: {updated_count}")

if __name__ == '__main__':
    migrate_users()
