CREATE TABLE members (
    member_id CHAR(50),
    member_name VARCHAR(200) NOT NULL,
    member_phoneno BIGINT NOT NULL,
    member_address VARCHAR(500) NOT NULL,
    PRIMARY KEY(member_id),
    CHECK(member_phoneno BETWEEN 1000000000 and 9999999999)
);

CREATE TABLE staff (
    staff_id CHAR(50),
    staff_name VARCHAR(200) NOT NULL,
    staff_role VARCHAR(50) NOT NULL,
    PRIMARY KEY(staff_id),
    CHECK(staff_role IN ('TRAINER', 'RECEPTIONIST', 'CLEANER', 'MANAGER'))
);

CREATE TABLE branches (
    branch_id CHAR(50),
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
    service_type_id CHAR(50),
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
    session_id CHAR(100),
    service_type_id CHAR(50) NOT NULL,
    trainer_id CHAR(50) NOT NULL,
    branch_id CHAR(50) NOT NULL,
    schedule_time TIMESTAMP NOT NULL,
    total_seats INT NOT NULL,
    remaining_seats INT NOT NULL,
    PRIMARY KEY(session_id),
    FOREIGN KEY(service_type_id) REFERENCES service_types(service_type_id),
    FOREIGN KEY(trainer_id) REFERENCES staff(staff_id),
    FOREIGN KEY(branch_id) REFERENCES branches(branch_id),
    CHECK(total_seats>0),
    CHECK(remaining_seats BETWEEN 0 and total_seats)
);

-- CREATE TABLE takes_session (
--     staff_id CHAR(50),
--     session_id CHAR(100),
--     PRIMARY KEY(staff_id, session_id),
--     FOREIGN KEY(staff_id) REFERENCES staff(staff_id),
--     FOREIGN KEY(session_id) REFERENCES class_sessions(session_id)
-- );

-- CREATE TABLE has_session (
--     service_type_id CHAR(50),
--     session_id CHAR(100),
--     PRIMARY KEY(service_type_id, session_id),
--     FOREIGN KEY(service_type_id) REFERENCES service_types(service_type_id),
--     FOREIGN KEY(session_id) REFERENCES class_sessions(session_id)
-- );

-- CREATE TABLE hosts_session (
--     branch_id CHAR(50),
--     session_id CHAR(100),
--     PRIMARY KEY(branch_id, session_id),
--     FOREIGN KEY(branch_id) REFERENCES branches(branch_id),
--     FOREIGN KEY(session_id) REFERENCES class_sessions(session_id)
-- );

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
    plan_id CHAR(5),
    tier_name VARCHAR(50) NOT NULL UNIQUE,
    fee INT NOT NULL,
    duration INT NOT NULL,
    PRIMARY KEY(plan_id), 
    CHECK(fee>0),
    CHECK(duration>0)
);

CREATE TABLE subscriptions (
    member_id CHAR(50),
    plan_id CHAR(5),
    branch_id CHAR(50),
    payment_date DATE,
    start_date DATE,
    expiry_date DATE NOT NULL,
    status VARCHAR(10) NOT NULL,
    PRIMARY KEY(member_id, plan_id, branch_id, payment_date, start_date),
    FOREIGN KEY(member_id) REFERENCES members(member_id),
    FOREIGN KEY(plan_id) REFERENCES membership_plans(plan_id),
    FOREIGN KEY(branch_id) REFERENCES branches(branch_id)
);

CREATE TABLE inventory_items (
    item_id CHAR(50),
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
