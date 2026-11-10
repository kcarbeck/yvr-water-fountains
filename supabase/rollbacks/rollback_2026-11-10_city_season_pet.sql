-- =====================================================================
-- ROLLBACK for supabase/data_fixes/2026-11-10_city_season_pet.sql
-- ---------------------------------------------------------------------
-- Puts back operational_status, season_note, pet_friendly, anti_freeze
-- and updated_at for the 243 fountains the fix can touch, as they were in
-- the backup taken 2026-11-10 (backups/2026-11-10/, before the fix).
-- Generated from that backup; tested on a local copy, where checksums.sql
-- and a full-row md5 of public.fountains came back identical to the
-- pre-fix database.
--
-- Run it only if these fountains have not been edited since the fix: the
-- fix stamps all 243 with one updated_at, so the check below stops if any
-- of them has a different one.
-- =====================================================================
begin;

do $$
begin
  if (select count(distinct updated_at) from public.fountains
      where external_id in (select column1 from (values
        ('DFENG0001'), ('DFENG0002'), ('DFENG0003'), ('DFENG0004'), ('DFENG0005'), ('DFENG0006'),
        ('DFENG0007'), ('DFENG0008'), ('DFENG0010'), ('DFENG0011'), ('DFENG0012'), ('DFENG0013'),
        ('DFENG0014'), ('DFENG0015'), ('DFENG0016'), ('DFENG0017'), ('DFENG0018'), ('DFENG0019'),
        ('DFENG0020'), ('DFENG0021'), ('DFENG0022'), ('DFENG0023'), ('DFENG0024'), ('DFENG0025'),
        ('DFENG0026'), ('DFENG0027'), ('DFENG0028'), ('DFENG0029'), ('DFENG0030'), ('DFENG0031'),
        ('DFENG0032'), ('DFENG0033'), ('DFENG0034'), ('DFENG0035'), ('DFENG0036'), ('DFENG0037'),
        ('DFENG0038'), ('DFENG0039'), ('DFENG0040'), ('DFENG0041'), ('DFENG0042'), ('DFENG0043'),
        ('DFENG0044'), ('DFENG0045'), ('DFENG0046'), ('DFENG0047'), ('DFENG0048'), ('DFENG0049'),
        ('DFENG0050'), ('DFENG0051'), ('DFENG0052'), ('DFENG0053'), ('DFENG0054'), ('DFENG0500'),
        ('DFENG0501'), ('DFENG0502'), ('DFENG0503'), ('DFENG0504'), ('DFENG0505'), ('DFENG0601'),
        ('DFENG0602'), ('DFENG0603'), ('DFENG0604'), ('DFENG0605'), ('DFENG0606'), ('DFENG0607'),
        ('DFENG0608'), ('DFENG0609'), ('DFENG0702'), ('DFENG0703'), ('DFENG0705'), ('DFENG0706'),
        ('DFENG0707'), ('DFENG0708'), ('DFENG0710'), ('DFENG0711'), ('DFENG0801'), ('DFENG0802'),
        ('DFENG0803'), ('DFENG0804'), ('DFENG0805'), ('DFENG0806'), ('DFENG0807'), ('DFENG0808'),
        ('DFENG0809'), ('DFENG0810'), ('DFENG0811'), ('DFPB0001'), ('DFPB0002'), ('DFPB0003'),
        ('DFPB0004'), ('DFPB0005'), ('DFPB0006'), ('DFPB0007'), ('DFPB0008'), ('DFPB0009'),
        ('DFPB0010'), ('DFPB0011'), ('DFPB0012'), ('DFPB0013'), ('DFPB0014'), ('DFPB0016'),
        ('DFPB0017'), ('DFPB0018'), ('DFPB0019'), ('DFPB0021'), ('DFPB0022'), ('DFPB0023'),
        ('DFPB0024'), ('DFPB0025'), ('DFPB0027'), ('DFPB0029'), ('DFPB0032'), ('DFPB0033'),
        ('DFPB0034'), ('DFPB0035'), ('DFPB0036'), ('DFPB0037'), ('DFPB0038'), ('DFPB0041'),
        ('DFPB0042'), ('DFPB0043'), ('DFPB0044'), ('DFPB0045'), ('DFPB0046'), ('DFPB0047'),
        ('DFPB0048'), ('DFPB0049'), ('DFPB0050'), ('DFPB0051'), ('DFPB0052'), ('DFPB0053'),
        ('DFPB0054'), ('DFPB0055'), ('DFPB0056'), ('DFPB0058'), ('DFPB0059'), ('DFPB0060'),
        ('DFPB0061'), ('DFPB0062'), ('DFPB0063'), ('DFPB0064'), ('DFPB0065'), ('DFPB0066'),
        ('DFPB0066-EF'), ('DFPB0067'), ('DFPB0074'), ('DFPB0075'), ('DFPB0076'), ('DFPB0077'),
        ('DFPB0078'), ('DFPB0079'), ('DFPB0080'), ('DFPB0081'), ('DFPB0082'), ('DFPB0083'),
        ('DFPB0084'), ('DFPB0085'), ('DFPB0086'), ('DFPB0087'), ('DFPB0088'), ('DFPB0089'),
        ('DFPB0090'), ('DFPB0093'), ('DFPB0094'), ('DFPB0095'), ('DFPB0096'), ('DFPB0097'),
        ('DFPB0098'), ('DFPB0099'), ('DFPB0100'), ('DFPB0101'), ('DFPB0103'), ('DFPB0104'),
        ('DFPB0105'), ('DFPB0107'), ('DFPB0108'), ('DFPB0109'), ('DFPB0110'), ('DFPB0111'),
        ('DFPB0112'), ('DFPB0113'), ('DFPB0114'), ('DFPB0115'), ('DFPB0116'), ('DFPB0117'),
        ('DFPB0118'), ('DFPB0120'), ('DFPB0123'), ('DFPB0124'), ('DFPB0125'), ('DFPB0126'),
        ('DFPB0127'), ('DFPB0128'), ('DFPB0129'), ('DFPB0130'), ('DFPB0131'), ('DFPB0132'),
        ('DFPB0133'), ('DFPB0134'), ('DFPB0135'), ('DFPB0136'), ('DFPB0137'), ('DFPB0138'),
        ('DFPB0139'), ('DFPB0140'), ('DFPB0141'), ('DFPB0142'), ('DFPB0143'), ('DFPB0145'),
        ('DFPB0146'), ('DFPB0147'), ('DFPB0151'), ('DFPB0152'), ('DFPB0153'), ('DFPB0155'),
        ('DFPB0156'), ('DFPB0158'), ('DFPB0160'), ('DFPB0161'), ('DFPB0162'), ('DFPB0163'),
        ('DFPB0164'), ('DFPB0165'), ('DFPB0167'), ('DFPB0168'), ('DFPB0169'), ('DFPB0170'),
        ('DFPB0171'), ('DFPB0172'), ('DFPB0173'), ('DFPB0174'), ('DFPB0175'), ('DFPB0176'),
        ('DFPB0177'), ('DFPB0178'), ('DFPB0179'), ('DFPB0180'), ('DFPB0181'), ('DFPB0182'),
        ('DFPB0183'), ('DFPB0184'), ('DFPB0185')
      ) ids)) <> 1 then
    raise exception 'rollback_city_season_pet: some of these fountains were edited after the fix';
  end if;
end $$;

-- the updated_at trigger would stamp "now" on every restored row
alter table public.fountains disable trigger fountains_touch_updated_at;

update public.fountains f
set operational_status = v.operational_status,
    season_note        = v.season_note,
    pet_friendly       = v.pet_friendly,
    anti_freeze        = v.anti_freeze,
    updated_at         = v.updated_at::timestamptz
from (values
  ('e7cfd520-d396-4501-81ca-dca4f25898cc', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0001
  ('db8266a6-c775-4987-9ed4-97623b58fc77', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0002
  ('f53fd36c-14ed-4f7b-afb5-190636895aba', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0003
  ('807eb59d-1bca-41b1-845c-0a19988a63e1', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0004
  ('b00d5146-d556-4be1-a0a8-5c7412e11392', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0005
  ('c4cb174b-ac45-46ca-a587-432c3348b088', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0006
  ('e21fd2a4-17dc-4419-90dc-d428e8e49016', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0007
  ('f8fc7add-c778-4722-a8a5-c93961f290f5', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0008
  ('cefebffe-74f8-4ad8-acae-4af19375e0e8', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0010
  ('3d1628f2-fa46-4fcd-ba46-b8ca7d28a64e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0011
  ('f6c47053-afb4-435f-bc0d-b41bebdc73b8', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0012
  ('45975e72-bb99-4c48-9479-3fb279e9de91', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0013
  ('fadf02b6-7ab1-4e61-a25d-fd52ed900ee8', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0014
  ('6b19cbb0-2251-4cda-8742-dd7a8799b9e3', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0015
  ('51b3dbce-c003-49ab-ac51-03b5ba50d203', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0016
  ('ae895910-f24d-4e53-a5e3-a2b407829a0f', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0017
  ('5b1f4bf1-cd07-4689-84af-924954e62fbd', 'unknown', null, 'unknown', false, '2026-10-31T19:19:18.309882+00:00'),  -- DFENG0018
  ('6cad62bc-29a6-478a-b450-1caead38a707', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0019
  ('9e3a7be5-a16c-414a-84b8-5616b714845f', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0020
  ('e01888f3-bcf8-4ea4-ab8b-a347dc2bb0b4', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0021
  ('de058b8b-7933-4e8b-b01f-119f9369ed5b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0022
  ('6d7023f0-110a-45f4-bc71-987113911817', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0023
  ('bb86bc34-c13b-4d80-a83b-634b83fef228', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0024
  ('47353076-79c8-4ca7-b5c0-8043ef59405c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0025
  ('91ea35d1-fadc-4e37-93cf-5210bc3a0ff3', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0026
  ('172c4f4b-6520-42e3-aa62-f0b1a9b114fa', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0027
  ('3f8f0a2e-48f3-4ec5-bdd2-68414ccfc8f5', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0028
  ('f7d7d839-d081-4fe6-bbb0-5dfd56f46a22', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0029
  ('a91bb345-292c-40eb-b4e3-df1a39f2c4a4', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0030
  ('6b1c9f81-4f5a-45af-b2b3-a802ad0ad96b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0031
  ('d0a36f84-3d00-40bb-a24b-24c1e60c623a', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0032
  ('273d1932-b499-48db-806c-ab8fa47a711b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0033
  ('0f409263-3f1d-433a-a896-35f4114953d9', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0034
  ('e233dd79-63cf-41ba-bd3f-b94fb042f766', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0035
  ('2eebcf6d-3850-4a33-bc5d-68c61d2c1317', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0036
  ('a688916e-d9d0-41e1-974f-f88ca75b0ee7', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0037
  ('51047af1-c947-4bf3-b508-a28bae8d2f8c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0038
  ('251dba3c-cc59-4f80-ad61-d1ef4b093c3c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0039
  ('f8ddf6b5-e386-45f0-aefc-2d083d5907ce', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0040
  ('f3379172-05e3-4fad-b795-f48cbb8d44a5', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0041
  ('dbecbf6f-4a4e-4bc8-b2c0-1b2a88eb635e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0042
  ('f28e58d3-5b85-4232-b622-1ad4c6ca4f55', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0043
  ('850ef87d-810d-4911-a191-db847917476b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0044
  ('c148e838-e939-41b2-a089-53519f68d1aa', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0045
  ('50ba420f-afb8-4249-97d1-c944da60b22e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0046
  ('8bcad041-9deb-4b0d-8148-13674f83057e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0047
  ('1a07803e-3d8c-49e1-b70d-e251a8704940', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0048
  ('ca3fef02-215c-4223-846c-aa3d9c08f4b1', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0049
  ('a154c935-59bf-4dd1-beec-17f0ddfaadbe', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0050
  ('8323e3fd-1c44-4a24-901f-339e6d62e089', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0051
  ('e32956b3-dcf4-47b1-972f-8f9b245de9ff', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0052
  ('03a765fe-c8db-4821-a123-3b165600ad3d', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0053
  ('773b8cdf-ac13-49f3-a335-2a6ddd1f7bf4', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0054
  ('4fd96a1d-409b-4df1-83a7-15eea55e0520', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0500
  ('2ed6d2b1-bbc4-4a91-a3d5-746355764282', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0501
  ('e62b5c6b-6fd4-44f2-b7e4-43051c8cd5e5', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0502
  ('2145cab8-a99f-4489-876a-64d2fef6adab', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0503
  ('fe7a383c-e9ef-4967-b973-e2d4ea930cbd', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0504
  ('1da65fe9-ce5c-4b56-97cd-8232773e356b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0505
  ('865296c1-e08a-4ae0-ae2a-3b36bac0903e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0601
  ('a8c0c76a-03e2-4cd5-b2e4-c1a40ba1a6f6', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0602
  ('2663947b-1e8e-427a-a074-829d5ed722df', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0603
  ('ecbea285-bcb8-46fe-951e-b04a431c582b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0604
  ('6e3242b5-dcdf-4bdb-897f-2adb8b068ae1', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0605
  ('b044d646-4aae-45d2-92f3-58e9be1ea35e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0606
  ('0692ae57-bc19-48ae-b07e-6e41e449a418', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0607
  ('f0d410a7-08c3-41c3-b001-9db93d557d0d', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0608
  ('631bd23a-9552-4f8f-8b75-89451fb6b2a3', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0609
  ('2341209f-56c0-4875-b6dd-fffde4e34357', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0702
  ('d82909b1-15b9-4f9b-a14b-b58b88c0d164', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0703
  ('b1a9e632-2e49-4bd3-9ce6-abcaaad7e5c8', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0705
  ('c3ac75c7-5fb4-4cda-a3d7-f9ce684b4b59', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0706
  ('9f2f7a58-b40a-4719-ae0f-e407005864ef', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0707
  ('453af02b-c970-4ddd-9c75-996377080646', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0708
  ('7f3906ca-10d5-421c-8e18-e432fab17e69', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0710
  ('9f280b4a-ee76-4f49-b33e-29506ade9fc0', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0711
  ('c8f95616-7f4c-45f9-a4a0-92527ab506e6', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0801
  ('5baea1b5-ff10-4016-bb1b-6652e06ad5ac', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0802
  ('fca74f73-2649-403a-b629-0e2ac126c2bf', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0803
  ('f992c789-3bb0-49e0-9d55-d70acae71351', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0804
  ('f68b8f7e-24da-4e59-b88c-8759dc49e337', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0805
  ('3749e488-98f1-43c7-8fda-f8557449c7d2', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0806
  ('bae37d06-acbf-4e30-b5bc-858e541963e2', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0807
  ('998e7df3-99ac-407b-9e57-507c991a1a5c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0808
  ('788b3003-397c-48dc-89f0-8771623cb5bd', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0809
  ('ef416dbe-7aaa-4bf1-b1f4-baf08fbe40fd', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0810
  ('4638a938-c2b4-4923-ab55-9c796e0c675a', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFENG0811
  ('75926ffe-d334-4b2d-b3bb-00c896132eba', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0001
  ('1be75504-3305-4623-b711-75348453357c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0002
  ('45741ae8-6ee2-4a4e-be12-d679e0982ed6', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0003
  ('fc66aee4-fe6a-4a4b-9958-40d5740f289b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0004
  ('dbd3320f-9865-4284-bc4c-616db9ad9986', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0005
  ('fb8d42f3-04fc-4569-8d73-65ba5339f135', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0006
  ('5e93d689-f1c1-404e-918a-fb9bf9803352', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0007
  ('fbcc7201-a9b7-440a-85b9-1b1049e38ee5', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0008
  ('afc1be11-b957-445b-940d-b66a24045c64', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0009
  ('3bb28bb6-70ae-4e8c-b1f1-fa0edbb45e60', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0010
  ('60084b45-c8e8-43c3-90bc-60fe9690e598', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0011
  ('732b92db-e180-4e42-810f-35d7c021fb69', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0012
  ('f00ed3af-0651-492e-9288-d0c97e9e9bcc', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0013
  ('66ce8c36-3c07-4e11-a17d-dae9f869a50e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0014
  ('97990855-d67a-412d-bfe8-6b4b4c6988ee', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0016
  ('835bac4e-9553-4052-87c3-bb2e254312f1', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0017
  ('0d624fcc-f051-4263-8561-20a65eb68213', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0018
  ('6b4e53aa-5d27-4eef-b66c-cfd6b3b415cb', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0019
  ('ac123914-30b1-4d47-af34-4714b5746ba4', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0021
  ('2fdcbafe-8f48-4814-9b0b-5d8550eddd9a', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0022
  ('0105e112-2cf0-4331-8537-703af0adcf85', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0023
  ('f3931be3-c01b-46dd-b399-2c2c8ddfb0c4', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0024
  ('fe901005-727a-48bd-bf4d-f1b44f2b3863', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0025
  ('b4f9490e-f394-4f15-9629-1524f42c5a48', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0027
  ('4fcc9473-da52-4ed9-9847-9b574c31f91b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0029
  ('333d41eb-5b15-48e5-b172-770b4c2085c9', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0032
  ('dccc86a6-64d8-4420-af14-5f19881aac1c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0033
  ('e3d19323-3ee7-41d8-bf49-4c913d187d0d', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0034
  ('e133e912-4470-4751-887a-7440bb0c061b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0035
  ('bba5a2b4-133a-4677-a3d9-c73f21a7706b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0036
  ('02d599de-2fe0-465a-bbb5-644fce6b7824', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0037
  ('cf8f7b03-bcbb-42be-95e2-d3f5345f3ccd', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0038
  ('50640451-0126-4589-8b53-8ff95d908789', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0041
  ('572dd1c5-dbc1-4935-8c27-461eb09dd7de', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0042
  ('3be0027b-e475-463d-bdc3-9a6f4d7f8a6d', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0043
  ('fb524145-c790-4572-ab9a-c93f6175c272', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0044
  ('a64d02e2-226d-42e0-a8da-13082d9c5b46', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0045
  ('ef409c70-2ce4-45d4-a5a6-54f34d07669d', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0046
  ('b18af709-2b4f-4f2e-a625-dfb92fe92609', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0047
  ('929d5c2e-2771-49c8-91d1-3af9abe18aa1', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0048
  ('5de1c4a1-d6a6-40c8-8735-21e1e2fcf219', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0049
  ('92184d2e-6b46-40aa-a226-cbf4adc96e92', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0050
  ('3ab07622-de06-4feb-ac44-36e778675147', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0051
  ('a08056ad-2f0a-40c7-a2fd-f538591f4d47', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0052
  ('21a16319-9abb-4e98-a385-355367834436', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0053
  ('7165fe8c-756a-44a7-abbc-5d3bd623d400', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0054
  ('585e38af-73b7-4007-91f7-947e9b0806b1', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0055
  ('f3b3bb22-d172-44ca-8570-62e5c5b9ba28', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0056
  ('e65f91cb-95ad-4946-bc57-40e2214c9570', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0058
  ('dcb3afe0-db6f-48f4-b3b2-37373bdbc55c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0059
  ('9f7d94ae-6cd3-474d-83ae-7343aec3f649', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0060
  ('c5e0e178-1c1f-47fe-8a1c-443e62fa4b7e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0061
  ('15a167c7-e486-4d1d-874b-883ca4c2a984', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0062
  ('0453b103-d409-4827-9e7c-e876bcb154ed', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0063
  ('156a09b2-a51a-46bd-aa5f-13946eae0e7f', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0064
  ('09b837e2-f5d0-493a-b3d1-5c9c1b421a56', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0065
  ('f0e2825e-47ec-424f-a850-c52f77c4e92e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0066
  ('6ec2113f-c4d6-4dee-8d22-b5a57ddbcd9b', 'seasonal', 'spring to fall', 'unknown', null, '2026-10-26T01:35:51.411803+00:00'),  -- DFPB0066-EF
  ('7f10136d-b866-4306-b500-0b4cc2a0191f', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0067
  ('d3bb76f4-7a82-4734-8277-6e455cc253d5', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0074
  ('4d9bf093-9144-49b2-bd69-ffa2d6b2716f', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0075
  ('2ebd6f2d-20ed-4ac6-81eb-3fb580244a35', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0076
  ('f5818d5e-dfbb-43d0-9965-78db5f4e9602', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0077
  ('06f07ea4-38be-497a-8ae5-2c565e754546', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0078
  ('6eff8e63-b31a-427a-b78c-43747fab0dc6', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0079
  ('0738d055-49df-4b2c-8602-fae9ac5b04ca', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0080
  ('45178d0e-39e6-461c-8d78-e21e702f53d8', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0081
  ('282c8c19-b097-4efd-99c5-afc2364fec73', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0082
  ('a9e4d918-32a9-46a2-b921-8145bfa11990', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0083
  ('976bfd8d-1e98-4904-b7c8-989972ca4ba4', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0084
  ('80931c2d-4aa8-45a1-817b-611cdd7f78a2', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0085
  ('6d7244db-3df8-4cdf-b52f-c4d898d2b093', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0086
  ('5404dd0e-0298-43df-ac93-30e95f742ca1', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0087
  ('b91cb553-1266-472d-b291-4cef4475f326', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0088
  ('64d97bd1-dd20-4a51-8808-e17766fa6f41', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0089
  ('33ff9c2c-6aeb-42a9-9fdc-a80d80290c6a', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0090
  ('982aa3f7-3a4e-4997-b82a-e5afb479973f', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0093
  ('0b6dc900-f05d-4f90-ab11-9c3fb22a5754', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0094
  ('d23b9938-e966-4041-a037-6202aa0b88d0', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0095
  ('a2c4c3ab-5bd7-42bf-9cab-622c0fc711db', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0096
  ('e852e5a9-8af0-4ccf-8b6e-5500a6589c74', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0097
  ('5b4dbe09-d1f2-4417-b1bf-eb77b698a194', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0098
  ('f638bd76-2448-4643-94a5-777430c82fda', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0099
  ('b884d87b-9ba2-4bb8-b2f5-136d810e0855', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0100
  ('0921c092-f5e1-4ae3-b142-23b1b74cd786', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0101
  ('78d03b4f-6931-413f-bdf2-ce978f6eebb4', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0103
  ('ec822884-32f5-41db-8b36-396b7b61b50c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0104
  ('9a150afe-7bc7-4022-8776-c662ce58828c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0105
  ('1e94e489-cdf3-4810-8cc5-9a4e6a3eee94', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0107
  ('59ebef6c-39cc-41e1-8be1-cc906f41827e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0108
  ('b9b5a5e7-3f44-4071-8484-d9ab6c0b3305', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0109
  ('3cc32dd5-d2e5-42e0-8451-148f6d672b17', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0110
  ('82f5a7dc-1bd7-4293-a337-d30bae3a51a7', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0111
  ('5225acdc-f0fe-4526-80ad-7df079a5a5a2', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0112
  ('ccc0d74a-fcfe-45fb-9cc2-af2041f46170', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0113
  ('a743e629-3f6c-4244-a0da-1f5e6e374bee', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0114
  ('0922ac21-ac17-4b5c-beca-79bf28508604', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0115
  ('82444473-ffbb-4731-8ceb-bf83d4b5470c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0116
  ('0ab2606d-e90b-4df5-b6ea-9bcec9dffd13', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0117
  ('1e89f1ca-879d-4b50-b27a-b657583c8abc', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0118
  ('49631ffa-782c-467d-a9de-64f86ffbfb8c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0120
  ('2200d355-e1a7-4400-8e1f-a87887bf9446', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0123
  ('767fde85-6f1f-4f79-af40-104de39f5ec5', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0124
  ('d5ee0056-9f93-4cc8-b4b4-25c131e93e49', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0125
  ('dfa25db3-e34e-48bd-ab42-3a8a082ac50d', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0126
  ('120b026e-9788-43b6-b058-749cb4cdaa92', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0127
  ('d9153936-d2df-4fcd-9d62-5f996ecabf6c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0128
  ('96c7e24b-34ad-4587-8e84-a5746a2823d6', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0129
  ('993f3015-b99c-47e1-aee0-7b2553fc9453', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0130
  ('56ab45cf-b033-4e04-9c67-72494e703887', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0131
  ('7741c67a-7207-489f-868b-773b305700e8', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0132
  ('cf0af71c-73d0-47d4-8c61-69098fa36281', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0133
  ('d6b9ea09-bc77-4547-9ef5-ab7c4904a7d7', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0134
  ('809dbcac-b042-48fe-bb31-030c1fa9fef4', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0135
  ('678ad7f8-5356-44a0-908f-425bae0234ce', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0136
  ('33067687-f09c-410d-9914-ec53e576f64b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0137
  ('94a9c699-789b-4b89-a54e-7d790fc0837b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0138
  ('1128a467-4ece-4987-9000-6d8be9193e95', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0139
  ('90d67568-11e4-4625-bae1-3ebf44a5eb09', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0140
  ('5e5902c0-5bfc-4b1f-a10a-9a73db0d0e89', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0141
  ('44135cb7-c865-4eb1-863f-e56789797732', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0142
  ('4e8ab709-d517-47d7-8a60-1c8c055fee6c', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0143
  ('5a286288-c784-46a4-a150-04069ddd1f83', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0145
  ('872f0d84-a42d-443e-b5e3-bd8b272766b5', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0146
  ('f45d1b70-47fb-42be-9a06-456c689ce6a7', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0147
  ('3e203ab0-3dff-43f0-9877-973422d9a126', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0151
  ('32fe8569-a555-4b6f-970e-a6051f698564', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0152
  ('cc746a75-6040-4e31-8109-f5974da05444', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0153
  ('fe4302c6-d7a6-4f7e-8e0e-052ebc468a60', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0155
  ('b0a55c8a-c906-4bb5-936c-1d39b06aabc4', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0156
  ('835b469c-8b9d-4bf4-aba1-d020c3e1d98e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0158
  ('21712df4-249a-4a59-8d37-f3416ca92c71', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0160
  ('349fd4e0-ebe3-4ac7-aff6-55ec9af9336b', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0161
  ('31b3180c-77e6-4221-af4a-505af8a8aa21', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0162
  ('aa51bed2-2ec1-48a9-974c-4dd6b6eb855f', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0163
  ('6089911f-2258-4177-adad-8a83ba384bae', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0164
  ('129ce3cc-a325-4d3c-a2c9-696fca93ba03', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0165
  ('6c2e2b5a-3c5f-44ff-b14d-62e1770f652d', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0167
  ('238fcd6f-c260-4f40-93ef-91a101f76089', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0168
  ('406820af-b312-481a-add4-c53bd2f37146', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0169
  ('90330da7-7b0c-4239-9d72-c93210cab796', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0170
  ('89ea26c0-0da2-45d7-9699-c7c0d9613305', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0171
  ('2988d6d2-46ca-4b0c-a3ca-58709e3f6d6e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0172
  ('e59cc7b4-2d26-4a51-8cb3-c544ed6585d3', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0173
  ('ca9443bd-09db-4b29-bd08-57bd02ae9de0', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0174
  ('7cbf868f-4a59-4b41-a6c3-2671b9d058d1', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0175
  ('ec062ab9-b076-4a0d-8889-f3b14291e580', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0176
  ('b2084e0e-4c1a-4b04-9650-6c70c90bd958', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0177
  ('80dbf1f2-a36a-4ed0-bfa9-85e5b40bad59', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0178
  ('425d8bff-7630-4ea3-b9c0-4fd673cf646a', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0179
  ('c7a001fc-5217-42fa-bdf2-6faca1c89b24', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0180
  ('edd067c8-3873-4722-b67e-4904009c009f', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0181
  ('6a293829-7b6f-46ee-966b-fd3dcf42cd21', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0182
  ('4f619e0f-2111-4dda-b36c-b6880d359d04', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0183
  ('7a12a990-e7e0-420e-96d9-5a6103f423d3', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00'),  -- DFPB0184
  ('4815b3a7-6a89-4a08-8b12-17ad8462e60e', 'unknown', null, 'unknown', null, '2026-03-03T01:14:26.454286+00:00')  -- DFPB0185
) as v(id, operational_status, season_note, pet_friendly, anti_freeze, updated_at)
where f.id = v.id::uuid;

alter table public.fountains enable trigger fountains_touch_updated_at;

commit;
