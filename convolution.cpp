#include <iostream>
#include <vector>
#include <fstream>
#include <sstream>
using namespace std;

// Function to write the convolution result to a file
void writeToFile(const vector<vector<float>>& result, ofstream& outfile)
{
    for(int i = 0; i < result.size(); i++)
    {
        for(int j = 0; j < result[i].size(); j++)
        {
            outfile << result[i][j];
            if(j != result[i].size() - 1)
                outfile << '\t';
            else
                outfile << '\n';
        }
    }
}

// Function to print the convolution result to the console
void print(const vector<vector<float>>& result)
{
    for(int i = 0; i < result.size(); i++)
    {
        for(int j = 0; j < result[i].size(); j++) // Fixed loop condition
        {
            cout << result[i][j] << '\t';
        }
        cout << '\n';
    }
}

// Function to perform convolution on the padded image
vector<vector<float>> convolution(const vector<vector<float>>& padded_img, const vector<vector<float>>& filt, int N, int M, int p, int s)
{
    int output_size = (N + 2*p - M) / s + 1;
    vector<vector<float>> result(output_size, vector<float>(output_size, 0));

    // Perform convolution
    for(int r = 0; r < output_size; r++)
    {
        for(int c = 0; c < output_size; c++)
        {
            float sum = 0;
            for(int i = 0; i < M; i++)
            {
                for(int j = 0; j < M; j++)
                {
                    sum += padded_img[r*s + i][c*s + j] * filt[i][j];
                }
            }
            result[r][c] = sum;
        }
    }

    // Print the result to the console
    print(result);

    return result;
}

int main()
{
    // Open the input file
    ifstream infile("input_matrix.txt");
    if(!infile.is_open())
    {
        cerr << "Error: Unable to open input_matrix.txt" << endl;
        return 1;
    }

    // Read the first line: N, M, p, s
    int N, M, p, s;
    infile >> N >> M >> p >> s;

    // Validate input constraints
    if(N < 3 || N > 7 || M < 2 || M > 4 || p < 0 || p > 4 || s < 1 || s > 3)
    {
        cerr << "Error: Input values out of allowed range." << endl;
        return 1;
    }

    // Create a padded image of size (N + 2p) x (N + 2p), initialized with zeros
    int padded_size = N + 2 * p;
    vector<vector<float>> padded_image(padded_size, vector<float>(padded_size, 0.0));

    // Read the image matrix and place it into the padded image
    for(int i = 0; i < N; i++)
    {
        for(int j = 0; j < N; j++)
        {
            if(!(infile >> padded_image[i + p][j + p]))
            {
                cerr << "Error: Not enough elements for image matrix." << endl;
                return 1;
            }
        }
    }

    // Read the filter matrix
    vector<vector<float>> filter(M, vector<float>(M, 0.0));
    for(int i = 0; i < M; i++)
    {
        for(int j = 0; j < M; j++)
        {
            if(!(infile >> filter[i][j]))
            {
                cerr << "Error: Not enough elements for filter matrix." << endl;
                return 1;
            }
        }
    }

    infile.close();

    // Perform convolution on the padded image
    vector<vector<float>> convolutionResult = convolution(padded_image, filter, N, M, p, s);

    // Open the output file
    ofstream outfile("output_matrix.txt");
    if(!outfile.is_open())
    {
        cerr << "Error: Unable to open output_matrix.txt" << endl;
        return 1;
    }

    // Write the convolution result to the output file
    writeToFile(convolutionResult, outfile);

    outfile.close();
    
    return 0;
}
