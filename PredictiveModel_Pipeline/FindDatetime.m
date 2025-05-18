function locina = FindDatetime(a,b)
% FINDDATETIME Find indices of elements in matrix a that match any element in vector b
%   locina = FindDatetime(a, b) returns linear indices of elements in matrix a
%   that exactly match any element in column vector b. The output indices are
%   sorted and unique.

    indices=zeros(size(a));

    % Iterate through each element in vector b
    for i=1:length(b)
        % Find positions where matrix elements match current element b(i)
        matchingIndices=(a==b(i));
      
         % Convert logical values to numerical (0/1) and accumulate matches
        indices_tmp=double(matchingIndices);
        indices=indices+indices_tmp;
    end
    
    locina=find(indices==1);
end

