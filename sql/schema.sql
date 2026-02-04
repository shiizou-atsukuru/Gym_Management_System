CREATE TABLE members (
    internal_id SERIAL,
    member_id CHAR(50) GENERATED ALWAYS AS (
    'M' || LPAD(internal_id::text, 49, '0')
    ) STORED, 
    member_name VARCHAR(200) NOT NULL,
    member_phoneno BIGINT NOT NULL,
    member_address VARCHAR(500) NOT NULL,
    PRIMARY KEY(member_id),
    CHECK(member_phoneno BETWEEN 1000000000 and 9999999999)
);

CREATE TABLE staff (
    internal_id SERIAL,
    staff_id CHAR(50) GENERATED ALWAYS AS (
    'E' || LPAD(internal_id::text, 49, '0')
    ) STORED, 
    staff_name VARCHAR(200) NOT NULL,
    staff_role VARCHAR(50) NOT NULL,
    PRIMARY KEY(staff_id),
    CHECK(staff_role IN ('TRAINER', 'RECEPTIONIST', 'CLEANER', 'MANAGER'))
);

CREATE TABLE branches (
    internal_id SERIAL,
    branch_id CHAR(50) GENERATED ALWAYS AS (
    'B' || LPAD(internal_id::text, 49, '0')
    ) STORED, 
    branch_address VARCHAR(500) NOT NULL,
    branch_capacity INT NOT NULL,
    manager_id CHAR(50) NOT NULL,
    PRIMARY KEY(branch_id),
    FOREIGN KEY(manager_id) REFERENCES staff(staff_id),
    CHECK(branch_capacity BETWEEN 1 AND 500)
);

CREATE TABLE works_at (
    staff_id CHAR(50),
    branch_id CHAR(50),
    PRIMARY KEY(staff_id, branch_id),
    FOREIGN KEY(staff_id) REFERENCES staff(staff_id),
    FOREIGN KEY(branch_id) REFERENCES branches(branch_id)
);

CREATE TABLE service_types (
    internal_id SERIAL,
    service_type_id CHAR(50) GENERATED ALWAYS AS (
    'SE' || LPAD(internal_id::text, 48, '0')
    ) STORED, 
    service_name VARCHAR(50) NOT NULL UNIQUE,
    PRIMARY KEY(service_type_id)
);

CREATE TABLE trainer_specialization (
    trainer_id CHAR(50),
    service_type_id CHAR(50),
    PRIMARY KEY(trainer_id, service_type_id),
    FOREIGN KEY(trainer_id) REFERENCES staff(staff_id),
    FOREIGN KEY(service_type_id) REFERENCES service_types(service_type_id)
);

CREATE TABLE class_sessions (
    internal_id SERIAL,
    session_id CHAR(100) GENERATED ALWAYS AS (
    'SS' || LPAD(internal_id::text, 98, '0')
    ) STORED, 
    service_type_id CHAR(50) NOT NULL,
    trainer_id CHAR(50) NOT NULL,
    branch_id CHAR(50) NOT NULL,
    schedule_time TIMESTAMP NOT NULL,
    total_seats INT NOT NULL,
    PRIMARY KEY(session_id),
    FOREIGN KEY(service_type_id) REFERENCES service_types(service_type_id),
    FOREIGN KEY(trainer_id) REFERENCES staff(staff_id),
    FOREIGN KEY(branch_id) REFERENCES branches(branch_id),
    CHECK(total_seats>0)
);

CREATE TABLE booking (
    session_id CHAR(100),
    member_id CHAR(50),
    PRIMARY KEY(session_id, member_id),
    FOREIGN KEY(member_id) REFERENCES members(member_id),
    FOREIGN KEY(session_id) REFERENCES class_sessions(session_id)
);

CREATE TABLE offered_services (
    branch_id CHAR(50),
    service_type_id CHAR(50),
    PRIMARY KEY(branch_id, service_type_id),
    FOREIGN KEY(branch_id) REFERENCES branches(branch_id),
    FOREIGN KEY(service_type_id) REFERENCES service_types(service_type_id)
);

CREATE TABLE membership_plans (
    internal_id SERIAL,
    plan_id CHAR(5) GENERATED ALWAYS AS (
    'P' || LPAD(internal_id::text, 4, '0')
    ) STORED, 
    tier_name VARCHAR(50) NOT NULL UNIQUE,
    fee INT NOT NULL,
    duration INT NOT NULL,
    PRIMARY KEY(plan_id), 
    CHECK(fee>0),
    CHECK(duration>0)
);

CREATE TABLE subscriptions (
    internal_id SERIAL,
    subscription_id char(100) GENERATED ALWAYS AS (
    'SU' || LPAD(internal_id::text, 98, '0')
    ) STORED,
    member_id CHAR(50),
    plan_id CHAR(5),
    branch_id CHAR(50),
    payment_date DATE,
    start_date DATE,
    PRIMARY KEY(subscription_id),
    FOREIGN KEY(member_id) REFERENCES members(member_id),
    FOREIGN KEY(plan_id) REFERENCES membership_plans(plan_id),
    FOREIGN KEY(branch_id) REFERENCES branches(branch_id),
    UNIQUE(member_id, plan_id, branch_id, payment_date)
);

CREATE TABLE inventory_items (
    internal_id SERIAL,
    item_id CHAR(50) GENERATED ALWAYS AS (
    'I' || LPAD(internal_id::text, 49, '0')
    ) STORED, 
    item_name VARCHAR(100) NOT NULL UNIQUE,
    PRIMARY KEY(item_id)
);

CREATE TABLE branch_inventories (
    branch_id CHAR(50),
    item_id CHAR(50),
    quantity INT,
    PRIMARY KEY(branch_id, item_id),
    FOREIGN KEY(branch_id) REFERENCES branches(branch_id),
    FOREIGN KEY(item_id) REFERENCES inventory_items(item_id),
    CHECK(quantity>0)
);


-- Views

CREATE OR REPLACE VIEW session_availability AS
SELECT 
    cs.session_id,
    cs.branch_id,
    st.service_name,
    s.staff_name AS trainer_name,
    cs.schedule_time,
    cs.total_seats,
    -- Calculate remaining seats dynamically
    (cs.total_seats - COUNT(b.member_id)) AS actual_remaining_seats
FROM 
    class_sessions cs
JOIN 
    service_types st ON cs.service_type_id = st.service_type_id
JOIN 
    staff s ON cs.trainer_id = s.staff_id
LEFT JOIN 
    booking b ON cs.session_id = b.session_id
GROUP BY 
    cs.session_id, st.service_name, s.staff_name, cs.schedule_time, cs.branch_id, cs.total_seats;


CREATE OR REPLACE VIEW subscription_details AS
SELECT 
    s.subscription_id,
    s.member_id,
    s.start_date,
    -- Calculate expiry_date: start_date + plan duration (in months)
    (s.start_date + (p.duration || ' months')::interval)::date AS computed_expiry_date,
    -- Calculate status based on that new expiry date
    CASE 
        WHEN (s.start_date + (p.duration || ' months')::interval)::date >= CURRENT_DATE THEN 'ACTIVE'
        ELSE 'EXPIRED'
    END AS computed_status
FROM 
    subscriptions s
JOIN 
    membership_plans p ON s.plan_id = p.plan_id;