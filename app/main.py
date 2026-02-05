import psycopg2
from psycopg2.extras import execute_values
from faker import Faker
import random
from datetime import date, datetime, timedelta
import time


fake = Faker()

def generate_dummy_data(cur, conn):
    print("Starting high-volume dummy data generation...")

    # 1. Service Types
    services = ['Yoga', 'Zumba', 'Weightlifting', 'Cardio', 'Pilates', 'Crossfit', 'Boxing']
    service_ids = []
    for s in services:
        cur.execute("INSERT INTO service_types (service_name) VALUES (%s) RETURNING service_type_id;", (s,))
        service_ids.append(cur.fetchone()[0])

    # 2. Membership Plans
    plans = [('Basic', 1000, 1), ('Standard', 2500, 3), ('Premium', 4500, 6), ('Elite', 8000, 12)]
    plan_ids = []
    for p in plans:
        cur.execute("INSERT INTO membership_plans (tier_name, fee, duration) VALUES (%s, %s, %s) RETURNING plan_id;", p)
        plan_ids.append(cur.fetchone()[0])

    # 3. Staff (Batch Insert for 1800 members)
    print("--- Inserting 1800 Staff...")
    staff_roles = ['MANAGER'] * 100 + ['TRAINER'] * 1000 + ['RECEPTIONIST'] * 200 + ['CLEANER'] * 500
    staff_data = [(fake.name(), role) for role in staff_roles]
    execute_values(cur, "INSERT INTO staff (staff_name, staff_role) VALUES %s", staff_data)
    
    # Retrieve IDs for Foreign Key usage
    cur.execute("SELECT staff_id FROM staff WHERE staff_role = 'MANAGER';")
    manager_ids = [r[0] for r in cur.fetchall()]
    cur.execute("SELECT staff_id FROM staff WHERE staff_role = 'TRAINER';")
    trainer_ids = [r[0] for r in cur.fetchall()]

    # 4. Branches (100)
    print("--- Inserting 100 Branches...")
    branch_ids = []
    for _ in range(100):
        cur.execute("""
            INSERT INTO branches (branch_address, branch_capacity, manager_id) 
            VALUES (%s, %s, %s) RETURNING branch_id;
        """, (fake.street_address(), random.randint(50, 500), random.choice(manager_ids)))
        branch_ids.append(cur.fetchone()[0])

    # 5. Members (10,000)
    print("--- Generating 10,000 Unique Members...")
    phone_numbers = set()
    member_data = []

    while len(member_data) < 10000:
        # Generate a random 10-digit number
        num = random.randint(1000000000, 9999999999)
        
        # Only add to list if the phone number hasn't been used yet in this batch
        if num not in phone_numbers:
            phone_numbers.add(num)
            member_data.append((
                fake.name(), 
                num, 
                fake.city()
            ))

    # Batch insert with ON CONFLICT safety 
    # This is the only insert call you need
    execute_values(cur, """
        INSERT INTO members (member_name, member_phoneno, member_address) 
        VALUES %s 
        ON CONFLICT (member_phoneno) DO NOTHING
    """, member_data)

    # Retrieve IDs to use for Subscriptions and Bookings
    cur.execute("SELECT member_id FROM members;")
    member_ids = [r[0] for r in cur.fetchall()]
    print(f"Successfully inserted {len(member_ids)} unique members.")

    # 6. Trainer Specializations
    spec_data = [(tid, random.choice(service_ids)) for tid in trainer_ids]
    execute_values(cur, "INSERT INTO trainer_specialization (trainer_id, service_type_id) VALUES %s ON CONFLICT DO NOTHING", spec_data)

    # 7. Subscriptions (15,000)
    print("--- Inserting 15,000 Subscriptions...")
    sub_data = []
    today = date.today()
    
    for i in range(15000):
        m_id = random.choice(member_ids)
        p_id = random.choice(plan_ids)
        b_id = random.choice(branch_ids)
        
        # Logic: 9000 Active (recent), 6000 Expired (old)
        if i < 9000:
            start_date = today - timedelta(days=random.randint(0, 20))
        else:
            start_date = today - timedelta(days=random.randint(400, 500))
            
        # payment_date is usually the same as start_date for this simulation
        sub_data.append((m_id, p_id, b_id, start_date, start_date))
    
    # Use ON CONFLICT to ignore the rare random duplicates
    execute_values(cur, """
        INSERT INTO subscriptions (member_id, plan_id, branch_id, payment_date, start_date) 
        VALUES %s 
        ON CONFLICT (member_id, plan_id, branch_id, payment_date) DO NOTHING
    """, sub_data)

    # 8. Inventory
    items = ['Treadmill', 'Dumbbell Set', 'Yoga Mat', 'Bench Press', 'Kettlebell']
    item_ids = []
    for item in items:
        cur.execute("INSERT INTO inventory_items (item_name) VALUES (%s) RETURNING item_id;", (item,))
        item_ids.append(cur.fetchone()[0])
    
    inv_data = []
    for bid in branch_ids:
        for iid in item_ids:
            inv_data.append((bid, iid, random.randint(5, 50)))
    execute_values(cur, "INSERT INTO branch_inventories (branch_id, item_id, quantity) VALUES %s", inv_data)

    # 9. Class Sessions (300)
    print("--- Inserting 300 Class Sessions (Capacity 1, 10, or 30)...")
    session_data = []
    for _ in range(300):
        # Pick specifically from your requested values
        capacity = random.choice([1, 10, 30])
            
        session_data.append((
            random.choice(service_ids), 
            random.choice(trainer_ids), 
            random.choice(branch_ids), 
            datetime.now() + timedelta(days=random.randint(1, 14)), 
            capacity
        ))
    
    # Insert and retrieve IDs and capacities for the booking step
    execute_values(cur, """
        INSERT INTO class_sessions (service_type_id, trainer_id, branch_id, schedule_time, total_seats) 
        VALUES %s RETURNING session_id, total_seats
    """, session_data)
    
    sessions = cur.fetchall() 

    # 10. Bookings
    print("--- Generating Bookings (Ensuring 1-capacity sessions are filled)...")
    booking_data = []
    
    for session_id, capacity in sessions:
        if capacity == 1:
            # Individual sessions must always be booked (100% full)
            num_to_fill = 1
        elif capacity == 10:
            # Randomly fill between 5 and 10 members
            num_to_fill = random.randint(5, 10)
        else: # capacity == 30
            # Randomly fill between 15 and 30 members
            num_to_fill = random.randint(15, 30)
        
        # Select random unique members
        attendees = random.sample(member_ids, num_to_fill)
        for m_id in attendees:
            booking_data.append((session_id, m_id))

    # Batch insert bookings
    execute_values(cur, "INSERT INTO booking (session_id, member_id) VALUES %s ON CONFLICT DO NOTHING", booking_data)


    conn.commit()
    print("Successfully populated database!")


if __name__ == "__main__":
    conn = None
    cur = None

    for attempt in range(10):
        try:
            conn = psycopg2.connect(
                host="db",
                database="GYM_MANAGEMENT_SYSTEM",
                user="root",
                password="hello"
            )
            print("Successfully connected to the database!")
            break
        except psycopg2.OperationalError:
            print("Database not ready, retrying...")
            time.sleep(2)
    else:
        raise RuntimeError("Database never became available")

    try:
        cur = conn.cursor()
        generate_dummy_data(cur, conn)
    except Exception as e:
        print(f"An error occurred: {e}")
        conn.rollback()
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()

