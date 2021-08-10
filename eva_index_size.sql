
exec dbms_stats.gather_table_stats(user,'CUST');

set serverout on
variable used_bytes number
variable alloc_bytes number
exec dbms_space.create_index_cost( 'create index cust_idx2 on cust(first_name)', -
               :used_bytes, :alloc_bytes );
print :used_bytes
print :alloc_bytes
