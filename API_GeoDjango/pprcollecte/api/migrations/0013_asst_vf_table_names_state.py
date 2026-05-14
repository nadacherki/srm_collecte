from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0012_ep_vf_table_names_state"),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[],
            state_operations=[
                migrations.AlterModelTable(
                    name="assregard",
                    table='"asst"."ASS_REGARD"',
                ),
                migrations.AlterModelTable(
                    name="assregardbranchement",
                    table='"asst"."ASS_REGARD_FACADE"',
                ),
                migrations.AlterModelTable(
                    name="asscanalisation",
                    table='"asst"."ASS_COLLECTEUR"',
                ),
                migrations.AlterModelTable(
                    name="asscanalisationreutilisation",
                    table='"asst"."ASS_REFOULEMENTR"',
                ),
                migrations.AlterModelTable(
                    name="assbranchement",
                    table='"asst"."ASS_BRANCHEMENT"',
                ),
                migrations.AlterModelTable(
                    name="assbassin",
                    table='"asst"."ASS_BASSIN_VERSANT"',
                ),
                migrations.AlterModelTable(
                    name="assouvrage",
                    table='"asst"."ASS_OUV_TRAVERSEE"',
                ),
                migrations.AlterModelTable(
                    name="assequipement",
                    table='"asst"."ASS_POMPE"',
                ),
                migrations.AlterModelTable(
                    name="assstation",
                    table='"asst"."ASS_STA_POMP"',
                ),
            ],
        ),
    ]
