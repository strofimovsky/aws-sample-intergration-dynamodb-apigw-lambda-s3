all: terraform.state

destroy:
	terraform destroy

%.zip:%.py
	zip $@ $<

terraform.state: example.tf dataimport.zip apicall.zip index.html
	terraform apply
