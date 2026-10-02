CREATE TABLE inventory_runs (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id text NOT NULL,
    object_count bigint NOT NULL,
    total_bytes bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
