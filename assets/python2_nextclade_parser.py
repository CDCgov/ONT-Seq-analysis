import os

# user input for directory path
def get_directory_input(prompt):
    return raw_input(prompt)  # Use raw_input for Python 2

def check_mutation(mutation, known_mutations):
    if mutation in known_mutations:
        return "yes"
    else:
        return "no"

def get_add_value(mutation, nomenclature_dict):
    return nomenclature_dict.get(mutation, "unknown")  # Return 'unknown' if mutation not found

# remove the file extension and keep the base filename
def get_filename_without_extension(file_path):
    return os.path.splitext(os.path.basename(file_path))[0]

# Function to remove "_clean" part from the base filename
def get_filename_without_clean(file_path):
    base_name = get_filename_without_extension(file_path)
    return base_name.replace('_clean', '')  

def main():
    # prompt user
    directory_path = get_directory_input("Please enter the path to the directory containing the files: ")

    # list of known mutations from Daisy
    known_mutations = [
        "G29923A", "C30730T", "G31039A", "C31081T", "A31102G", "C31529T", "T32867C", "T33102A", 
        "C33159T", "A33656C", "T36049C", "G36445A", "G37170T", "T39248C", "A73076G", "C73350T", 
        "A75790G", "T76123C", "A76198G", "A76648G", "A76911G", "A78461C", "A78942G", "C79267T", 
        "C79502A", "A79829G", "T82688C", "T83360C", "T83843C", "T84290C", "A84395G", "C85763T", 
        "A86247G", "G86502T", "G86728A", "C35352A", "G75982A", "G77643A", "G86343A", "C30510T", 
        "G30699T", "C35859T", "C36732T", "T38382A", "G30367A", "G31053A", "G34459A", "G37202A", 
        "C38662T", "C39139T"
    ]

    # dictionary of muts to clade
    nomenclature_dict = {
        "G29923A": "Clade I", "C30730T": "Clade I", "C31081T": "Clade I", "A31102G": "Clade I", "C31529T": "Clade I",
        "T32867C": "Clade I", "T33102A": "Clade I", "C33159T": "Clade I", "A33656C": "Clade I", "T36049C": "Clade I",
        "G36445A": "Clade I", "C37170T": "Clade I", "T39248C": "Clade I", "A73076G": "Clade I", "C73350T": "Clade I",
        "A75790G": "Clade I", "T76123C": "Clade I", "A76198G": "Clade I", "A76648G": "Clade I", "A76911G": "Clade I",
        "A78461C": "Clade I", "A78942G": "Clade I", "C79267T": "Clade I", "C79502A": "Clade I", "A79829G": "Clade I",
        "T82688C": "Clade I", "T83360C": "Clade I", "T83843C": "Clade I", "T84290C": "Clade I", "A84395G": "Clade I",
        "C85763T": "Clade I", "A86247G": "Clade I", "G86502T": "Clade I", "G86728A": "Clade I", "C35352A": "Clade Ia",
        "G75982A": "Clade Ib", "G77643A": "Clade Ib", "G86343A": "Clade Ib", "C30510T": "Clade IIa", "G30699T": "Clade IIa",
        "C35859T": "Clade IIa", "C36732T": "Clade IIa", "T38382A": "Clade IIb Lineage B", "G30367A": "Clade IIb Lineage B", "G31053A": "Clade IIb Lineage B",
        "G34459A": "Clade IIb Lineage B", "G37202A": "Clade IIb Lineage B", "C38662T": "Clade IIb Lineage B", "C39139T": "Clade IIb Lineage B"
    }

    # Create the output directory if it doesn't exist
    output_directory = os.path.join(os.getcwd(), 'parsed')
    if not os.path.exists(output_directory):
        os.makedirs(output_directory)

    for filename in os.listdir(directory_path):
        # Process only files that end with '_clean.tsv'
        if filename.endswith('_clean.tsv'):
            input_file_path = os.path.join(directory_path, filename)
            
            base_filename = get_filename_without_clean(input_file_path)

            with open(input_file_path, 'r') as file:
                lines = file.readlines()

            header = lines[0].strip().split('\t')

            # Find the index of the column with the specified name
            try:
                column_index = header.index("founderMuts['clade'].substitutions")
            except ValueError:
                print("Error: Column 'founderMuts['clade'].substitutions' not found in file {}.".format(filename))
                continue

            output_file_path = os.path.join(output_directory, "{}_parsed.tsv".format(base_filename))

            # Create the output file and add the headers (change as needed)
            rows_to_write = []
            rows_to_write.append("seq_name\tMutations_found_on_sequence\tFound_in_Clade_I_or_Clade_II\tClade_designation\n")

            # Process the lines from the input file (skip the header)
            for line in lines[1:]:
                columns = line.strip().split('\t')  # Split the line by tab
                if len(columns) > column_index:
                    mutations = columns[column_index].split(',')  # Get the mutation column and split by commas
                    for mutation in mutations:
                        # Check if the mutation is in the known mutations list and write to the output file
                        result = check_mutation(mutation.strip(), known_mutations)
                        if result == "yes":
                            add_value = get_add_value(mutation.strip(), nomenclature_dict)
                        else:
                            add_value = "N/A"
                        # Prepend the base filename (without extension or _clean part) as the first column
                        rows_to_write.append("{}\t{}\t{}\t{}\n".format(base_filename, mutation.strip(), result, add_value))

            # Filter out rows where 'found_in_nomenclature' is "no"
            rows_to_write = [row for row in rows_to_write if "no" not in row]

            # Write the filtered rows back to the output file
            with open(output_file_path, 'w') as output_file:
                output_file.writelines(rows_to_write)

            print("Processed file '{}', output saved to '{}'.".format(filename, output_file_path))

if __name__ == "__main__":
    main()
