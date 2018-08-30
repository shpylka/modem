function hScopes = createScopes

persistent hScope
if isempty(hScope)
    hScope = QAMScopes;
end
hScopes = hScope;

end

