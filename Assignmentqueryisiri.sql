DROP TABLE IF EXISTS meter_readings CASCADE;
DROP TABLE IF EXISTS meters CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TYPE  IF EXISTS reading_type CASCADE;

CREATE TYPE reading_type AS ENUM ('Manual', 'Automatic', 'Estimated');

CREATE TABLE customers (
  customer_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name     TEXT NOT NULL,
  phone         TEXT,
  address       TEXT
);

CREATE TABLE meters (
  meter_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id   INT NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  meter_number  TEXT NOT NULL UNIQUE,
  active        BOOLEAN NOT NULL DEFAULT TRUE,
  installed_on  DATE DEFAULT CURRENT_DATE
);

CREATE TABLE meter_readings (
  meter_reading_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  meter_id          INT NOT NULL REFERENCES meters(meter_id) ON DELETE CASCADE,
  reading_date      DATE NOT NULL,
  previous_reading  NUMERIC(10,2) NOT NULL CHECK (previous_reading >= 0),
  current_reading   NUMERIC(10,2) NOT NULL CHECK (current_reading  >= 0), 
  units_consumed    NUMERIC(10,2) GENERATED ALWAYS AS (current_reading - previous_reading) STORED,
  reading_type      reading_type NOT NULL,
  status            BOOLEAN NOT NULL DEFAULT TRUE,  
  remarks           TEXT
);

CREATE INDEX idx_readings_meter_date ON meter_readings (meter_id, reading_date);
CREATE INDEX idx_meters_customer ON meters (customer_id);

INSERT INTO customers (full_name, phone, address) VALUES
('Isiri',  '1234567890', 'Jaraganahalli'),
('Akshay',      '2345678901', 'Konankunte cross'),
('Anupama',     '3456789012', 'RRnagar'),
('Prakash',   '4567890123', 'Yelachanahalli');

INSERT INTO meters (customer_id, meter_number, installed_on) VALUES
(1, 'ISI-1001', '2024-01-10'),
(2, 'AKS-1002', '2023-02-15'),
(3, 'ANU-1003', '2022-03-05'),
(4, 'PRA-1004', '2021-04-20'),
(2, 'AKS-1005', '2024-05-18'); 

INSERT INTO meter_readings (meter_id, reading_date, previous_reading, current_reading, reading_type, status, remarks) VALUES
(1, '2025-07-31', 1200.00, 1255.00, 'Manual',    TRUE, 'July reading'),
(2, '2025-07-31',  500.00,  540.00, 'Manual',    TRUE, 'July reading'),
(3, '2025-07-31',  740.00,  795.00, 'Automatic', TRUE, 'July reading'),
(4, '2025-07-31',  150.00,  170.00, 'Manual',    TRUE, 'July reading'),
(5, '2025-07-31',  200.00,  230.00, 'Estimated', TRUE, 'July reading');
INSERT INTO meter_readings (meter_id, reading_date, previous_reading, current_reading, reading_type, status, remarks) VALUES
(1, '2025-08-31', 1255.00, 1308.00, 'Automatic', TRUE, 'August reading'),
(2, '2025-08-31',  540.00,  600.00, 'Manual',    TRUE, 'August reading'), 
(3, '2025-08-31',  795.00,  820.00, 'Manual',    TRUE, 'August reading'),
(4, '2025-08-31',  170.00,  160.00, 'Estimated', TRUE, 'Suspicious: drop'),
(5, '2025-08-31',  230.00,  260.00, 'Automatic', TRUE, 'August reading');

--1.Find customers who consumed more than 50 units in August 2025
SELECT c.customer_id, c.full_name, ROUND(SUM(mr.units_consumed), 2) AS aug_units
FROM customers c
JOIN meters m ON m.customer_id = c.customer_id
JOIN meter_readings mr ON mr.meter_id = m.meter_id
WHERE mr.reading_date >= DATE '2025-08-01' AND mr.reading_date <  DATE '2025-09-01'
GROUP BY c.customer_id, c.full_name
HAVING SUM(mr.units_consumed) > 50
ORDER BY aug_units DESC;

--2.Get average units consumed by ReadingType
SELECT mr.reading_type, ROUND(AVG(mr.units_consumed), 2) AS avg_units
FROM meter_readings mr
GROUP BY mr.reading_type
ORDER BY mr.reading_type;

--3.Show the highest consumption reading per customer
SELECT customer_id, full_name, meter_reading_id, reading_date, units_consumed
FROM (
  SELECT c.customer_id, c.full_name, mr.meter_reading_id, mr.reading_date, mr.units_consumed,
    ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY mr.units_consumed DESC, mr.reading_date DESC, mr.meter_reading_id DESC) AS rn
  FROM customers c
  JOIN meters m  ON m.customer_id = c.customer_id
  JOIN meter_readings mr ON mr.meter_id = m.meter_id
) x
WHERE rn = 1
ORDER BY customer_id;

--4.Identify suspicious readings where the current reading is less than the previous
SELECT c.full_name, m.meter_number, mr.reading_date, mr.previous_reading, mr.current_reading, mr.units_consumed
FROM customers c
JOIN meters m  ON m.customer_id = c.customer_id
JOIN meter_readings mr ON mr.meter_id = m.meter_id
WHERE mr.current_reading < mr.previous_reading
ORDER BY mr.reading_date DESC;

--5.Find total units consumed per customer in July and August 2025
SELECT c.customer_id, c.full_name, ROUND(SUM(mr.units_consumed), 2) AS total_units_jul_aug
FROM customers c
JOIN meters m  ON m.customer_id = c.customer_id
JOIN meter_readings mr ON mr.meter_id = m.meter_id
WHERE mr.reading_date >= DATE '2025-07-01' AND mr.reading_date <  DATE '2025-09-01'
GROUP BY c.customer_id, c.full_name
ORDER BY total_units_jul_aug DESC;

--6.Rank the customers based on total consumption in July and August 2025
WITH total_consumption AS (
  SELECT c.customer_id, c.full_name, SUM(mr.units_consumed) AS total_units
  FROM customers c
  JOIN meters m  ON m.customer_id = c.customer_id
  JOIN meter_readings mr ON mr.meter_id = m.meter_id
  WHERE mr.reading_date >= DATE '2025-07-01' AND mr.reading_date <  DATE '2025-09-01'
  GROUP BY c.customer_id, c.full_name
)
SELECT customer_id, full_name, ROUND(total_units, 2) AS total_units_jul_aug,
  RANK() OVER (ORDER BY total_units DESC) AS rank_by_consumption
FROM total_consumption
ORDER BY rank_by_consumption, customer_id;

--7.Show last reading for each customer (most recent date)
SELECT DISTINCT ON (c.customer_id)
  c.customer_id, c.full_name, m.meter_number, mr.reading_date, mr.previous_reading, mr.current_reading, mr.units_consumed, mr.reading_type
FROM customers c
JOIN meters m  ON m.customer_id = c.customer_id
JOIN meter_readings mr ON mr.meter_id = m.meter_id
ORDER BY c.customer_id, mr.reading_date DESC, mr.meter_reading_id DESC;

--8.Create Stored Procedures to perform Insert/Update/Delete/View.
-- INSERT procedure
DROP PROCEDURE IF EXISTS sp_insert_meter_reading;
CREATE PROCEDURE sp_insert_meter_reading(
  p_meter_id INT,
  p_reading_date DATE,
  p_previous NUMERIC(10,2),
  p_current  NUMERIC(10,2),
  p_type     reading_type,
  p_status   BOOLEAN,
  p_remarks  TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO meter_readings (meter_id, reading_date, previous_reading, current_reading, reading_type, status, remarks)
  VALUES (p_meter_id, p_reading_date, p_previous, p_current, p_type, p_status, p_remarks);
END;
$$;

-- UPDATE procedure
DROP PROCEDURE IF EXISTS sp_update_meter_reading;
CREATE PROCEDURE sp_update_meter_reading(
  p_meter_reading_id INT,
  p_previous NUMERIC(10,2),
  p_current  NUMERIC(10,2),
  p_type     reading_type,
  p_status   BOOLEAN,
  p_remarks  TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE meter_readings
     SET previous_reading = p_previous,
         current_reading  = p_current,
         reading_type     = p_type,
         status           = p_status,
         remarks          = p_remarks
   WHERE meter_reading_id = p_meter_reading_id;
END;
$$;

-- DELETE procedure
DROP PROCEDURE IF EXISTS sp_delete_meter_reading;
CREATE PROCEDURE sp_delete_meter_reading(
  p_meter_reading_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM meter_readings WHERE meter_reading_id = p_meter_reading_id;
END;
$$;

CALL sp_insert_meter_reading(
  p_meter_id := 1,             
  p_reading_date := DATE '2025-09-30',
  p_previous := 1308.00,
  p_current  := 1360.00,
  p_type     := 'Manual',
  p_status   := TRUE,
  p_remarks  := 'September reading'
);

select * 
from meter_readings
where meter_id=1

CALL sp_update_meter_reading(
  p_meter_reading_id := 1,      -- the row you want to change
  p_previous := 1200.00,
  p_current  := 1256.00,
  p_type     := 'Manual',
  p_status   := TRUE,
  p_remarks  := 'Corrected value'
);

select * 
from meter_readings
where meter_reading_id=1

CALL sp_delete_meter_reading( p_meter_reading_id := 1 ); 

DROP FUNCTION IF EXISTS fn_view_meter_readings_by_customer(INT, DATE, DATE);
CREATE FUNCTION fn_view_meter_readings_by_customer(
  p_customer_id INT,
  p_from DATE DEFAULT NULL,
  p_to   DATE DEFAULT NULL
)
RETURNS TABLE (
  customer_id INT,
  full_name   TEXT,
  meter_number TEXT,
  reading_date DATE,
  previous_reading NUMERIC(10,2),
  current_reading  NUMERIC(10,2),
  units_consumed   NUMERIC(10,2),
  reading_type     reading_type,
  status           BOOLEAN,
  remarks          TEXT
)
LANGUAGE sql
AS $$
  SELECT
    c.customer_id,
    c.full_name,
    m.meter_number,
    mr.reading_date,
    mr.previous_reading,
    mr.current_reading,
    mr.units_consumed,
    mr.reading_type,
    mr.status,
    mr.remarks
  FROM customers c
  JOIN meters m  ON m.customer_id = c.customer_id
  JOIN meter_readings mr ON mr.meter_id = m.meter_id
  WHERE c.customer_id = p_customer_id
    AND (p_from IS NULL OR mr.reading_date >= p_from)
    AND (p_to   IS NULL OR mr.reading_date <= p_to)
  ORDER BY mr.reading_date;
$$;

SELECT * FROM fn_view_meter_readings_by_customer(1, '2025-08-01', '2025-08-31');