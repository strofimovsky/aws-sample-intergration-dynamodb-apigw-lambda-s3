all: terraform.state

destroy:
	terraform destroy

apicall.zip: apicall.py
	zip apicall.zip apicall.py

dataimport.zip: dataimport.py
	zip dataimport.zip dataimport.py

terraform.state: *.tf *.zip *.html
	terraform apply
