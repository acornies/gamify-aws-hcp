input_file = "workshop-studio-template.yaml"
output_file = "/Users/wellsiau/workspace/output/tmx/hashicorp-gameday-v1/static/cloudformation-templates/package.yaml"
with open(input_file, "r") as f_in:
    with open(output_file, "w") as f_out:
        for line in f_in:
            if "CodeUri:" in line:
                # print("Current line: "+line)
                spl = line.split('/')
                parsedLine = "      CodeUri: !Sub 's3://${LambdaPackageBucketName}/${LambdaPackageBucketPrefix}"+spl[4]+"'"
                newLine = line.replace(line, str(parsedLine))
                newLine = newLine.replace('\n', '')
                newLine = newLine + "\n"
                f_out.write(newLine)
            else:
                f_out.write(line)
print("Parsing finished")
